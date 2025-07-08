// internal/metrics/metrics_test.go
package metrics_test

import (

	// Added for http.ResponseWriter interface
	// Added for httptest.ResponseRecorder
	"strings"
	"testing"

	"github.com/prometheus/client_golang/prometheus"          // Added for promhttp.HandlerFor
	"github.com/prometheus/client_golang/prometheus/testutil" // Retained for final assertion

	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
)

// MockPrometheusMetrics (kept for reference, not directly used by NewPrometheusMetricsWithRegistry)
type MockPrometheusMetrics struct {
	IncHTTPStatusCounterFunc         func(statusCode int)
	ObserveKeyGenerationDurationFunc func(duration float64, length int)
}

func (m *MockPrometheusMetrics) IncHTTPStatusCounter(statusCode int) {
	if m.IncHTTPStatusCounterFunc != nil {
		m.IncHTTPStatusCounterFunc(statusCode)
	}
}

func (m *MockPrometheusMetrics) ObserveKeyGenerationDuration(duration float64, length int) {
	if m.ObserveKeyGenerationDurationFunc != nil {
		m.ObserveKeyGenerationDurationFunc(duration, length)
	}
}

func TestPrometheusMetrics_MetricsOutput(t *testing.T) {
	registry := prometheus.NewRegistry()
	const testMaxKeySize = 64 // Consistent maxKeySize for predictable buckets
	metricsSvc := metrics.NewPrometheusMetricsWithRegistry(registry, testMaxKeySize)

	metricsSvc.IncHTTPStatusCounter(200)
	metricsSvc.IncHTTPStatusCounter(404)
	metricsSvc.ObserveKeyGenerationDuration(0.01, 16) // duration 0.01, length 16
	metricsSvc.ObserveKeyGenerationDuration(0.05, 32) // duration 0.05, length 32

	/*
		// --- TEMPORARY: Print actual output to copy ---
		// UNCOMMENT THE FOLLOWING LINES, RUN THE TEST, COPY THE OUTPUT, THEN RE-COMMENT

		// Create a new HTTP recorder to capture the response body
		rec := httptest.NewRecorder()
		// Create a dummy HTTP request (method and path don't strictly matter for promhttp)
		req, _ := http.NewRequest("GET", "/metrics", nil)

		// Create a Prometheus HTTP handler for our specific registry
		handler := promhttp.HandlerFor(registry, promhttp.HandlerOpts{})

		// Serve the metrics using the handler, writing output to our recorder
		handler.ServeHTTP(rec, req)

		// The metrics output is now in rec.Body.String()
		fmt.Println("--- ACTUAL METRICS OUTPUT (COPY THIS EXACTLY) ---")
		fmt.Print(rec.Body.String())
		fmt.Println("--- END ACTUAL METRICS OUTPUT ---")
		// --- END TEMPORARY ---
	*/

	// IMPORTANT: Paste the EXACT output you copy from the terminal (after running the temporary code)
	// into this multiline string.
	expected := `# HELP http_requests_total Total number of HTTP requests by status code.
# TYPE http_requests_total counter
http_requests_total{code="200"} 1
http_requests_total{code="404"} 1
# HELP key_generation_duration_seconds Time taken to generate a key.
# TYPE key_generation_duration_seconds histogram
key_generation_duration_seconds_bucket{length="16",le="0"} 0
key_generation_duration_seconds_bucket{length="16",le="3.2"} 1
key_generation_duration_seconds_bucket{length="16",le="6.4"} 1
key_generation_duration_seconds_bucket{length="16",le="9.600000000000001"} 1
key_generation_duration_seconds_bucket{length="16",le="12.8"} 1
key_generation_duration_seconds_bucket{length="16",le="16"} 1
key_generation_duration_seconds_bucket{length="16",le="19.2"} 1
key_generation_duration_seconds_bucket{length="16",le="22.4"} 1
key_generation_duration_seconds_bucket{length="16",le="25.599999999999998"} 1
key_generation_duration_seconds_bucket{length="16",le="28.799999999999997"} 1
key_generation_duration_seconds_bucket{length="16",le="31.999999999999996"} 1
key_generation_duration_seconds_bucket{length="16",le="35.199999999999996"} 1
key_generation_duration_seconds_bucket{length="16",le="38.4"} 1
key_generation_duration_seconds_bucket{length="16",le="41.6"} 1
key_generation_duration_seconds_bucket{length="16",le="44.800000000000004"} 1
key_generation_duration_seconds_bucket{length="16",le="48.00000000000001"} 1
key_generation_duration_seconds_bucket{length="16",le="51.20000000000001"} 1
key_generation_duration_seconds_bucket{length="16",le="54.40000000000001"} 1
key_generation_duration_seconds_bucket{length="16",le="57.600000000000016"} 1
key_generation_duration_seconds_bucket{length="16",le="60.80000000000002"} 1
key_generation_duration_seconds_bucket{length="16",le="+Inf"} 1
key_generation_duration_seconds_sum{length="16"} 0.01
key_generation_duration_seconds_count{length="16"} 1
key_generation_duration_seconds_bucket{length="32",le="0"} 0
key_generation_duration_seconds_bucket{length="32",le="3.2"} 1
key_generation_duration_seconds_bucket{length="32",le="6.4"} 1
key_generation_duration_seconds_bucket{length="32",le="9.600000000000001"} 1
key_generation_duration_seconds_bucket{length="32",le="12.8"} 1
key_generation_duration_seconds_bucket{length="32",le="16"} 1
key_generation_duration_seconds_bucket{length="32",le="19.2"} 1
key_generation_duration_seconds_bucket{length="32",le="22.4"} 1
key_generation_duration_seconds_bucket{length="32",le="25.599999999999998"} 1
key_generation_duration_seconds_bucket{length="32",le="28.799999999999997"} 1
key_generation_duration_seconds_bucket{length="32",le="31.999999999999996"} 1
key_generation_duration_seconds_bucket{length="32",le="35.199999999999996"} 1
key_generation_duration_seconds_bucket{length="32",le="38.4"} 1
key_generation_duration_seconds_bucket{length="32",le="41.6"} 1
key_generation_duration_seconds_bucket{length="32",le="44.800000000000004"} 1
key_generation_duration_seconds_bucket{length="32",le="48.00000000000001"} 1
key_generation_duration_seconds_bucket{length="32",le="51.20000000000001"} 1
key_generation_duration_seconds_bucket{length="32",le="54.40000000000001"} 1
key_generation_duration_seconds_bucket{length="32",le="57.600000000000016"} 1
key_generation_duration_seconds_bucket{length="32",le="60.80000000000002"} 1
key_generation_duration_seconds_bucket{length="32",le="+Inf"} 1
key_generation_duration_seconds_sum{length="32"} 0.05
key_generation_duration_seconds_count{length="32"} 1
`
	// This final CollectAndCompare is the *actual* assertion for the test.
	if err := testutil.CollectAndCompare(registry, strings.NewReader(expected)); err != nil {
		t.Errorf("Unexpected metrics output:\n%s", err)
	}
}
