package metrics

import (
	"fmt" // Import fmt for string formatting

	"github.com/prometheus/client_golang/prometheus"
)

// DefaultRegistry is the default Prometheus registry.
// This is typically the global registry, but for testing, it's better to use NewRegistry().
var DefaultRegistry = prometheus.NewRegistry()

// PrometheusMetrics holds Prometheus collectors.
type PrometheusMetrics struct {
	httpRequestsTotal            *prometheus.CounterVec
	keyGenerationDurationSeconds *prometheus.HistogramVec
	keyGenerationsTotal          *prometheus.CounterVec // NEW: Add a counter for total key generations
}

// NewPrometheusMetricsWithRegistry creates and registers new Prometheus metrics.
// It accepts a registry to allow for isolated testing.
func NewPrometheusMetricsWithRegistry(registry *prometheus.Registry, maxKeySize int) *PrometheusMetrics {
	m := &PrometheusMetrics{
		httpRequestsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "http_requests_total",
				Help: "Total number of HTTP requests by status code.",
			},
			[]string{"code"},
		),
		keyGenerationDurationSeconds: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name: "key_generation_duration_seconds",
				Help: "Time taken to generate a key.",
				// Buckets are defined relative to the expected duration range.
				// This example uses linear buckets for simplicity.
				Buckets: prometheus.LinearBuckets(0, float64(maxKeySize)/20, 20), // Placeholder example
			},
			[]string{"length"},
		),
		// NEW: Initialize the keyGenerationsTotal counter
		keyGenerationsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "key_generations_total",
				Help: "Total number of key generation attempts by length and success status.",
			},
			[]string{"length", "status"}, // Labels for length and success/failure status
		),
	}

	// Register the collectors with the provided registry
	registry.MustRegister(m.httpRequestsTotal)
	registry.MustRegister(m.keyGenerationDurationSeconds)
	registry.MustRegister(m.keyGenerationsTotal) // NEW: Register the new counter

	return m
}

// IncHTTPStatusCounter increments the HTTP requests total counter for a given status code.
func (m *PrometheusMetrics) IncHTTPStatusCounter(statusCode int) {
	m.httpRequestsTotal.WithLabelValues(fmt.Sprintf("%d", statusCode)).Inc()
}

// ObserveKeyGenerationDuration observes the duration of key generation.
func (m *PrometheusMetrics) ObserveKeyGenerationDuration(duration float64, length int) {
	m.keyGenerationDurationSeconds.WithLabelValues(fmt.Sprintf("%d", length)).Observe(duration)
}

// RecordKeyGeneration records a key generation event.
// This method is added to satisfy the handler.MetricsService interface.
// It increments a counter based on the key length and whether the generation was successful.
func (m *PrometheusMetrics) RecordKeyGeneration(length int, success bool) {
	status := "failure"
	if success {
		status = "success"
	}
	// Increment the counter for key generation attempts
	m.keyGenerationsTotal.WithLabelValues(fmt.Sprintf("%d", length), status).Inc()

	// Note: The 'duration' is handled separately by ObserveKeyGenerationDuration.
	// If you wanted 'RecordKeyGeneration' to also include duration,
	// you'd need to add 'duration float64' to its parameters and the handler.MetricsService interface.
}
