package handler

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/bajhalshrey/Key-Server-Application/internal/keyservice"
	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
)

// HTTPHandler handles HTTP requests for the key server.
type HTTPHandler struct {
	keyService keyservice.KeyService  // <--- Uses the KeyService INTERFACE
	metricsSvc metrics.MetricsService // Uses the MetricsService INTERFACE
}

// NewHTTPHandler creates a new HTTPHandler instance.
func NewHTTPHandler(ks keyservice.KeyService, ms metrics.MetricsService) *HTTPHandler {
	return &HTTPHandler{
		keyService: ks,
		metricsSvc: ms,
	}
}

// HealthCheck handles the /health endpoint.
func (h *HTTPHandler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	h.metricsSvc.IncHTTPStatusCounter(http.StatusOK)
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "Healthy")
}

// ReadinessCheck handles the /ready endpoint.
func (h *HTTPHandler) ReadinessCheck(w http.ResponseWriter, r *http.Request) {
	h.metricsSvc.IncHTTPStatusCounter(http.StatusOK)
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "Ready to serve traffic!")
}

// GenerateKey handles the /key/{length} endpoint.
func (h *HTTPHandler) GenerateKey(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(r.URL.Path, "/")
	if len(parts) < 3 || parts[2] == "" {
		http.Error(w, "Invalid key length. Must be a positive integer.\n", http.StatusBadRequest)
		h.metricsSvc.IncHTTPStatusCounter(http.StatusBadRequest)
		return
	}
	lengthStr := parts[2]
	length, err := strconv.Atoi(lengthStr)
	if err != nil {
		http.Error(w, "Invalid key length. Must be a positive integer.\n", http.StatusBadRequest)
		h.metricsSvc.IncHTTPStatusCounter(http.StatusBadRequest)
		return
	}

	key, err := h.keyService.GenerateKey(length) // This call handles its own validation (length range)
	if err != nil {
		if strings.Contains(err.Error(), "out of allowed range") {
			http.Error(w, err.Error()+"\n", http.StatusBadRequest)
			h.metricsSvc.IncHTTPStatusCounter(http.StatusBadRequest)
			h.metricsSvc.RecordKeyGeneration(length, false)
			return
		}
		http.Error(w, fmt.Sprintf("Internal server error: Failed to generate key.\n"), http.StatusInternalServerError)
		h.metricsSvc.IncHTTPStatusCounter(http.StatusInternalServerError)
		h.metricsSvc.RecordKeyGeneration(length, false)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"key":"%s"}`+"\n", key)
	h.metricsSvc.IncHTTPStatusCounter(http.StatusOK)
	h.metricsSvc.RecordKeyGeneration(length, true)
}

// MetricsHandler returns the HTTP handler for Prometheus metrics.
func (h *HTTPHandler) MetricsHandler() http.Handler {
	return h.metricsSvc.MetricsHandler()
}
