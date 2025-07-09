package metrics

import (
	"net/http" // Required for http.Handler
	"strconv"  // Required for strconv.Itoa

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// MetricsService defines the interface for collecting application metrics.
type MetricsService interface {
	IncHTTPStatusCounter(statusCode int)
	IncrementKeyGenerationRequests()
	IncrementInvalidKeyLengthErrors()
	IncrementKeyGenerationErrors()
	ObserveKeyGenerationDuration(duration float64, length int)
	ObserveKeyLength(length float64)
	RecordKeyGeneration(length int, success bool) // <--- ADDED TO INTERFACE
	MetricsHandler() http.Handler                 // Returns an http.Handler for the /metrics endpoint
}

// PrometheusMetrics implements the MetricsService interface using Prometheus.
type PrometheusMetrics struct {
	httpRequestsTotal            *prometheus.CounterVec
	keyGenerationRequestsTotal   prometheus.Counter
	invalidKeyLengthErrorsTotal  prometheus.Counter
	keyGenerationErrorsTotal     prometheus.Counter
	keyGenerationDurationSeconds *prometheus.HistogramVec
	generatedKeyLengthBytes      prometheus.Histogram // <--- CHANGED: Removed '*' - now it's the interface type
	keyGenerationsTotal          *prometheus.CounterVec
	registry                     *prometheus.Registry // Store the registry
}

// NewPrometheusMetricsWithRegistry creates a new PrometheusMetrics instance with a custom registry.
func NewPrometheusMetricsWithRegistry(registry *prometheus.Registry, maxKeySize int) *PrometheusMetrics {
	m := &PrometheusMetrics{
		httpRequestsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "http_requests_total",
				Help: "Total number of HTTP requests by status code.",
			},
			[]string{"code"},
		),
		keyGenerationRequestsTotal: prometheus.NewCounter(
			prometheus.CounterOpts{
				Name: "key_server_key_generation_requests_total",
				Help: "Total number of key generation requests.",
			},
		),
		invalidKeyLengthErrorsTotal: prometheus.NewCounter(
			prometheus.CounterOpts{
				Name: "key_server_invalid_key_length_errors_total",
				Help: "Total number of key generation requests with invalid length.",
			},
		),
		keyGenerationErrorsTotal: prometheus.NewCounter(
			prometheus.CounterOpts{
				Name: "key_server_key_generation_errors_total",
				Help: "Total number of errors during key generation.",
			},
		),
		keyGenerationDurationSeconds: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "key_generation_duration_seconds",
				Help:    "Time taken to generate a key.",
				Buckets: prometheus.LinearBuckets(0, 3.2, 20), // Example buckets
			},
			[]string{"length"}, // Label for key length
		),
		generatedKeyLengthBytes: prometheus.NewHistogram( // <--- No '*' here
			prometheus.HistogramOpts{
				Name:    "key_server_generated_key_length_bytes",
				Help:    "Histogram of generated key lengths in bytes.",
				Buckets: prometheus.LinearBuckets(0, float64(maxKeySize/10), 10), // Example: 0, 10, 20...
			},
		),
		keyGenerationsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "key_generations_total",
				Help: "Total number of key generation attempts by length and success status.",
			},
			[]string{"length", "status"}, // Labels for length and success/failure
		),
		registry: registry, // Store the provided registry
	}

	// Register all metrics with the provided registry
	registry.MustRegister(m.httpRequestsTotal)
	registry.MustRegister(m.keyGenerationRequestsTotal)
	registry.MustRegister(m.invalidKeyLengthErrorsTotal)
	registry.MustRegister(m.keyGenerationErrorsTotal)
	registry.MustRegister(m.keyGenerationDurationSeconds)
	registry.MustRegister(m.generatedKeyLengthBytes) // <--- Now correctly registered
	registry.MustRegister(m.keyGenerationsTotal)

	return m
}

// NewPrometheusMetrics creates and registers Prometheus metrics using the default global registry.
func NewPrometheusMetrics() *PrometheusMetrics {
	return NewPrometheusMetricsWithRegistry(prometheus.DefaultRegisterer.(*prometheus.Registry), 1024)
}

// IncHTTPStatusCounter increments the counter for HTTP requests by status code.
func (m *PrometheusMetrics) IncHTTPStatusCounter(statusCode int) {
	m.httpRequestsTotal.WithLabelValues(strconv.Itoa(statusCode)).Inc()
}

// IncrementKeyGenerationRequests increments the total count of key generation requests.
func (m *PrometheusMetrics) IncrementKeyGenerationRequests() {
	m.keyGenerationRequestsTotal.Inc()
}

// IncrementInvalidKeyLengthErrors increments the total count of invalid key length errors.
func (m *PrometheusMetrics) IncrementInvalidKeyLengthErrors() {
	m.invalidKeyLengthErrorsTotal.Inc()
}

// IncrementKeyGenerationErrors increments the total count of key generation errors.
func (m *PrometheusMetrics) IncrementKeyGenerationErrors() {
	m.keyGenerationErrorsTotal.Inc()
}

// ObserveKeyGenerationDuration observes the duration of a key generation operation.
func (m *PrometheusMetrics) ObserveKeyGenerationDuration(duration float64, length int) {
	m.keyGenerationDurationSeconds.WithLabelValues(strconv.Itoa(length)).Observe(duration)
}

// ObserveKeyLength observes the length of a generated key.
func (m *PrometheusMetrics) ObserveKeyLength(length float64) {
	m.generatedKeyLengthBytes.Observe(length) // <--- Now correctly observed
}

// RecordKeyGeneration records a key generation attempt by length and success status.
func (m *PrometheusMetrics) RecordKeyGeneration(length int, success bool) { // <--- IMPLEMENTATION
	status := "failure"
	if success {
		status = "success"
	}
	m.keyGenerationsTotal.WithLabelValues(strconv.Itoa(length), status).Inc()
}

// MetricsHandler returns an http.Handler for the /metrics endpoint.
func (m *PrometheusMetrics) MetricsHandler() http.Handler {
	return promhttp.HandlerFor(m.registry, promhttp.HandlerOpts{})
}
