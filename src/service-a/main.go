// service-a — HTTP API simulator (orders endpoint)
// Generates synthetic Prometheus metrics, structured JSON logs (slog), and OTLP traces.
package main

import (
	"context"
	"encoding/json"
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
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
	"go.opentelemetry.io/otel/trace"
)

// ---------------------------------------------------------------------------
// Prometheus metrics
// ---------------------------------------------------------------------------

var (
	ordersTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "orders_total",
		Help: "Total number of orders processed",
	}, []string{"status", "region"})

	orderDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "order_processing_duration_seconds",
		Help:    "End-to-end order processing latency",
		Buckets: []float64{0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0},
	}, []string{"region"})

	orderErrorsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "order_errors_total",
		Help: "Total number of order errors",
	}, []string{"error_type"})

	activeOrders = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "active_orders_current",
		Help: "Number of orders currently being processed",
	})

	httpRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total HTTP requests",
	}, []string{"method", "path", "status_code"})
)

// ---------------------------------------------------------------------------
// Tracing init
// ---------------------------------------------------------------------------

func initTracer(ctx context.Context) (*sdktrace.TracerProvider, error) {
	endpoint := getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", "localhost:4318")

	exporter, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint(endpoint),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		return nil, fmt.Errorf("create OTLP exporter: %w", err)
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(getEnv("OTEL_SERVICE_NAME", "service-a")),
			semconv.ServiceVersion(getEnv("SERVICE_VERSION", "1.0.0")),
			attribute.String("deployment.environment", "demo"),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("create resource: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)

	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	return tp, nil
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

var regions = []string{"us-east-1", "us-west-2", "eu-west-1"}

func randomRegion() string {
	return regions[rand.Intn(len(regions))]
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "OK")
}

func ordersHandler(logger *slog.Logger) http.HandlerFunc {
	tracer := otel.Tracer("service-a/orders")

	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		region := randomRegion()

		ctx, span := tracer.Start(r.Context(), "process-order",
			trace.WithAttributes(
				attribute.String("order.region", region),
				attribute.String("http.method", r.Method),
			),
		)
		defer span.End()

		activeOrders.Inc()
		defer activeOrders.Dec()

		// Simulate variable processing latency: 10ms–800ms
		latency := time.Duration(10+rand.Intn(790)) * time.Millisecond
		time.Sleep(latency)

		status := "success"
		httpStatus := http.StatusOK

		// Simulate 4% error rate
		if rand.Float64() < 0.04 {
			status = "error"
			httpStatus = http.StatusInternalServerError
			errorType := []string{"timeout", "validation", "downstream"}[rand.Intn(3)]

			orderErrorsTotal.WithLabelValues(errorType).Inc()
			span.SetAttributes(attribute.Bool("error", true))
			span.SetAttributes(attribute.String("error.type", errorType))

			logger.ErrorContext(ctx, "order failed",
				"status", httpStatus,
				"region", region,
				"error_type", errorType,
				"duration_ms", time.Since(start).Milliseconds(),
				"traceID", span.SpanContext().TraceID().String(),
			)
		} else {
			logger.InfoContext(ctx, "order processed",
				"status", httpStatus,
				"region", region,
				"duration_ms", time.Since(start).Milliseconds(),
				"traceID", span.SpanContext().TraceID().String(),
			)
		}

		ordersTotal.WithLabelValues(status, region).Inc()
		orderDuration.WithLabelValues(region).Observe(time.Since(start).Seconds())
		httpRequestsTotal.WithLabelValues(r.Method, "/api/orders", fmt.Sprintf("%d", httpStatus)).Inc()

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(httpStatus)

		resp := map[string]any{
			"order_id":    fmt.Sprintf("ord-%d", rand.Int63n(100000)),
			"status":      status,
			"region":      region,
			"duration_ms": time.Since(start).Milliseconds(),
		}
		_ = json.NewEncoder(w).Encode(resp)
	}
}

// ---------------------------------------------------------------------------
// Synthetic load generator — runs in background
// ---------------------------------------------------------------------------

func startSyntheticLoad(ctx context.Context, addr string, logger *slog.Logger) {
	client := &http.Client{Timeout: 5 * time.Second}
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// Fire 1–5 concurrent synthetic requests
			n := 1 + rand.Intn(4)
			for i := 0; i < n; i++ {
				go func() {
					resp, err := client.Get(fmt.Sprintf("http://%s/api/orders", addr))
					if err != nil {
						logger.Warn("synthetic request failed", "error", err)
						return
					}
					resp.Body.Close()
				}()
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	// Initialize tracing
	tp, err := initTracer(ctx)
	if err != nil {
		logger.Error("failed to init tracer", "error", err)
		os.Exit(1)
	}
	defer func() {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := tp.Shutdown(shutdownCtx); err != nil {
			logger.Error("tracer shutdown error", "error", err)
		}
	}()

	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", healthzHandler)
	// Wrap orders handler with OTel HTTP instrumentation
	mux.Handle("/api/orders", otelhttp.NewHandler(ordersHandler(logger), "orders"))

	addr := ":8080"
	srv := &http.Server{
		Addr:         addr,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start synthetic load generator after a brief startup pause
	go func() {
		time.Sleep(5 * time.Second)
		startSyntheticLoad(ctx, "localhost"+addr, logger)
	}()

	go func() {
		logger.Info("service-a started", "addr", addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	logger.Info("shutting down")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("server shutdown error", "error", err)
	}
}
