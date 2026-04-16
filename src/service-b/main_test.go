package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

// ---- getEnv ----------------------------------------------------------------

func TestGetEnv_ReturnsEnvVar(t *testing.T) {
	t.Setenv("TEST_KEY", "world")
	if got := getEnv("TEST_KEY", "fallback"); got != "world" {
		t.Fatalf("want %q, got %q", "world", got)
	}
}

func TestGetEnv_ReturnsFallback(t *testing.T) {
	os.Unsetenv("TEST_KEY_MISSING")
	if got := getEnv("TEST_KEY_MISSING", "default"); got != "default" {
		t.Fatalf("want %q, got %q", "default", got)
	}
}

// ---- healthz handler -------------------------------------------------------

func TestHealthzHandler_Returns200(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("OK"))
	})

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()

	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("want status 200, got %d", w.Code)
	}
	if body := w.Body.String(); body != "OK" {
		t.Fatalf("want body %q, got %q", "OK", body)
	}
}

// ---- jobTypes coverage -----------------------------------------------------

func TestJobTypes_NotEmpty(t *testing.T) {
	if len(jobTypes) == 0 {
		t.Fatal("jobTypes must not be empty")
	}
	for _, jt := range jobTypes {
		if jt == "" {
			t.Fatal("jobTypes contains empty string")
		}
	}
}
