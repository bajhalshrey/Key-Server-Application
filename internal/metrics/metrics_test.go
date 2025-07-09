package metrics_test

import (
	"strings"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/testutil"

	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
)

// TestPrometheusMetrics_MetricsOutput tests that the metrics handler produces expected output
func TestPrometheusMetrics_MetricsOutput(t *testing.T) {
	registry := prometheus.NewRegistry()
	const testMaxKeySize = 64
	metricsSvc := metrics.NewPrometheusMetricsWithRegistry(registry, testMaxKeySize)

	// Simulate metric activity for ALL defined metrics
	metricsSvc.IncHTTPStatusCounter(200)
	metricsSvc.IncHTTPStatusCounter(404)

	metricsSvc.IncrementKeyGenerationRequests()
	metricsSvc.IncrementKeyGenerationRequests() // Two requests

	metricsSvc.IncrementInvalidKeyLengthErrors() // One invalid length error

	metricsSvc.IncrementKeyGenerationErrors() // One generation error

	metricsSvc.ObserveKeyLength(16) // Observe key length 16
	metricsSvc.ObserveKeyLength(32) // Observe key length 32

	metricsSvc.ObserveKeyGenerationDuration(0.01, 16) // duration 0.01, length 16
	metricsSvc.ObserveKeyGenerationDuration(0.05, 32) // duration 0.05, length 32

	metricsSvc.RecordKeyGeneration(16, true)  // Successful key generation of length 16
	metricsSvc.RecordKeyGeneration(32, false) // Failed key generation of length 32

	// --- TEMPORARY: Print actual output to copy ---
	// UNCOMMENT THE FOLLOWING LINES, RUN THE TEST, COPY THE OUTPUT, THEN RE-COMMENT

	// Create a new HTTP recorder to capture the response body
	//rec := httptest.NewRecorder()
	// Create a dummy HTTP request (method and path don't strictly matter for promhttp)
	//req_temp, _ := http.NewRequest("GET", "/metrics", nil)

	// Use the MetricsHandler from the PrometheusMetrics struct
	//handler_temp := metricsSvc.MetricsHandler()

	// Serve the metrics using the handler, writing output to our recorder
	//handler_temp.ServeHTTP(rec, req_temp)

	// The metrics output is now in rec.Body.String()
	//fmt.Println("--- ACTUAL METRICS OUTPUT (COPY THIS EXACTLY) ---")
	//fmt.Print(rec.Body.String())
	//fmt.Println("--- END ACTUAL METRICS OUTPUT ---")
	// --- END TEMPORARY ---

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
# HELP key_generations_total Total number of key generation attempts by length and success status.
# TYPE key_generations_total counter
key_generations_total{length="16",status="success"} 1
key_generations_total{length="32",status="failure"} 1
# HELP key_server_generated_key_length_bytes Histogram of generated key lengths in bytes.
# TYPE key_server_generated_key_length_bytes histogram
key_server_generated_key_length_bytes_bucket{le="0"} 0
key_server_generated_key_length_bytes_bucket{le="6"} 0
key_server_generated_key_length_bytes_bucket{le="12"} 0
key_server_generated_key_length_bytes_bucket{le="18"} 1
key_server_generated_key_length_bytes_bucket{le="24"} 1
key_server_generated_key_length_bytes_bucket{le="30"} 1
key_server_generated_key_length_bytes_bucket{le="36"} 2
key_server_generated_key_length_bytes_bucket{le="42"} 2
key_server_generated_key_length_bytes_bucket{le="48"} 2
key_server_generated_key_length_bytes_bucket{le="54"} 2
key_server_generated_key_length_bytes_bucket{le="+Inf"} 2
key_server_generated_key_length_bytes_sum 48
key_server_generated_key_length_bytes_count 2
# HELP key_server_invalid_key_length_errors_total Total number of key generation requests with invalid length.
# TYPE key_server_invalid_key_length_errors_total counter
key_server_invalid_key_length_errors_total 1
# HELP key_server_key_generation_errors_total Total number of errors during key generation.
# TYPE key_server_key_generation_errors_total counter
key_server_key_generation_errors_total 1
# HELP key_server_key_generation_requests_total Total number of key generation requests.
# TYPE key_server_key_generation_requests_total counter
key_server_key_generation_requests_total 2
` + "\n" // Added the missing newline character here.
	if err := testutil.CollectAndCompare(registry, strings.NewReader(expected)); err != nil {
		t.Errorf("Unexpected metrics output:\n%s", err)
	}
}
