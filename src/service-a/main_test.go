package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"log/slog"
)

// ---- getEnv ----------------------------------------------------------------

func TestGetEnv_ReturnsEnvVar(t *testing.T) {
	t.Setenv("TEST_KEY", "hello")
	if got := getEnv("TEST_KEY", "fallback"); got != "hello" {
		t.Fatalf("want %q, got %q", "hello", got)
	}
}

func TestGetEnv_ReturnsFallback(t *testing.T) {
	os.Unsetenv("TEST_KEY_MISSING")
	if got := getEnv("TEST_KEY_MISSING", "fallback"); got != "fallback" {
		t.Fatalf("want %q, got %q", "fallback", got)
	}
}

// ---- randomRegion ----------------------------------------------------------

func TestRandomRegion_ValidRegion(t *testing.T) {
	valid := map[string]bool{
		"us-east-1": true,
		"us-west-2": true,
		"eu-west-1": true,
	}
	for i := 0; i < 50; i++ {
		r := randomRegion()
		if !valid[r] {
			t.Fatalf("unexpected region %q", r)
		}
	}
}

// ---- healthzHandler --------------------------------------------------------

func TestHealthzHandler_Returns200(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()

	healthzHandler(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("want status 200, got %d", w.Code)
	}
	if body := w.Body.String(); body != "OK" {
		t.Fatalf("want body %q, got %q", "OK", body)
	}
}

// ---- ordersHandler ---------------------------------------------------------

func TestOrdersHandler_ReturnsValidStatus(t *testing.T) {
	// otel.Tracer falls back to the noop provider when no provider is registered — safe in tests.
	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))
	handler := ordersHandler(logger)

	req := httptest.NewRequest(http.MethodGet, "/api/orders", nil)
	w := httptest.NewRecorder()

	handler(w, req)

	code := w.Code
	if code != http.StatusOK && code != http.StatusInternalServerError {
		t.Fatalf("unexpected status %d — must be 200 or 500", code)
	}
	if ct := w.Header().Get("Content-Type"); ct != "application/json" {
		t.Fatalf("want Content-Type application/json, got %q", ct)
	}
}
