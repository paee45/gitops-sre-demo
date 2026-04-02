// service-b - Background worker simulator
package main

import (
	"context"
	"fmt"
	"log/slog"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
	"go.opentelemetry.io/otel/trace"
)

var (
	jobsProcessed = promauto.NewCounterVec(prometheus.CounterOpts{Name: "jobs_processed_total", Help: "Total jobs processed"}, []string{"job_type", "status"})
	jobFailures   = promauto.NewGaugeVec(prometheus.GaugeOpts{Name: "job_failures_current", Help: "Consecutive failures"}, []string{"job_type"})
	jobDuration   = promauto.NewHistogramVec(prometheus.HistogramOpts{Name: "job_duration_seconds", Help: "Job processing time", Buckets: []float64{0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0}}, []string{"job_type"})
	queueDepth    = promauto.NewGaugeVec(prometheus.GaugeOpts{Name: "worker_queue_depth", Help: "Simulated queue depth"}, []string{"job_type"})
)

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func initTracer(ctx context.Context) (*sdktrace.TracerProvider, error) {
	ep := getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", "localhost:4318")
	exporter, err := otlptracehttp.New(ctx, otlptracehttp.WithEndpoint(ep), otlptracehttp.WithInsecure())
	if err != nil { return nil, fmt.Errorf("create OTLP exporter: %w", err) }
	res, err := resource.New(ctx, resource.WithAttributes(
		semconv.ServiceName(getEnv("OTEL_SERVICE_NAME", "service-b")),
		semconv.ServiceVersion(getEnv("SERVICE_VERSION", "1.0.0")),
		attribute.String("deployment.environment", "demo"),
	))
	if err != nil { return nil, fmt.Errorf("create resource: %w", err) }
	tp := sdktrace.NewTracerProvider(sdktrace.WithBatcher(exporter), sdktrace.WithResource(res), sdktrace.WithSampler(sdktrace.AlwaysSample()))
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{}))
	return tp, nil
}

var jobTypes = []string{"invoice-renderer", "notification-sender", "report-aggregator", "cache-warmer"}
var failureState = map[string]float64{}

func processJob(ctx context.Context, tracer trace.Tracer, logger *slog.Logger, jobType string) {
	start := time.Now()
	_, span := tracer.Start(ctx, "process-job", trace.WithAttributes(
		attribute.String("job.type", jobType),
		attribute.String("worker.id", getEnv("HOSTNAME", "worker-0")),
	))
	defer span.End()
	time.Sleep(time.Duration(5+rand.Intn(2995)) * time.Millisecond)
	status := "success"
	if rand.Float64() < 0.06 {
		status = "failure"
		failureState[jobType]++
		jobFailures.WithLabelValues(jobType).Set(failureState[jobType])
		span.SetAttributes(attribute.Bool("error", true))
		logger.ErrorContext(ctx, "job failed", "job_type", jobType, "consecutive_failures", failureState[jobType], "duration_ms", time.Since(start).Milliseconds(), "traceID", span.SpanContext().TraceID().String())
	} else {
		if failureState[jobType] > 0 { failureState[jobType] = 0; jobFailures.WithLabelValues(jobType).Set(0) }
		logger.InfoContext(ctx, "job completed", "job_type", jobType, "duration_ms", time.Since(start).Milliseconds(), "traceID", span.SpanContext().TraceID().String())
	}
	jobsProcessed.WithLabelValues(jobType, status).Inc()
	jobDuration.WithLabelValues(jobType).Observe(time.Since(start).Seconds())
	queueDepth.WithLabelValues(jobType).Add(float64(rand.Intn(5)) - 2)
}

func runWorker(ctx context.Context, logger *slog.Logger) {
	tracer := otel.Tracer("service-b/worker")
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for _, jt := range jobTypes { queueDepth.WithLabelValues(jt).Set(float64(rand.Intn(20))) }
	for {
		select {
		case <-ctx.Done(): return
		case <-ticker.C:
			for _, jt := range jobTypes { jt := jt; go processJob(ctx, tracer, logger, jt) }
		}
	}
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	tp, err := initTracer(ctx)
	if err != nil { logger.Error("failed to init tracer", "error", err); os.Exit(1) }
	defer func() {
		c, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		tp.Shutdown(c)
	}()
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK); fmt.Fprint(w, "OK") })
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadTimeout: 10 * time.Second, WriteTimeout: 15 * time.Second, IdleTimeout: 60 * time.Second}
	go func() {
		logger.Info("service-b started", "addr", ":8080")
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("server error", "error", err); os.Exit(1)
		}
	}()
	go runWorker(ctx, logger)
	<-ctx.Done()
	logger.Info("shutting down")
	c, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	srv.Shutdown(c)
}
