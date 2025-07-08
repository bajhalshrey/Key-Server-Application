package handler

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv" // For converting key length string to int

	"github.com/gorilla/mux" // For extracting path variables like {length}
	// Important: These are typically *not* directly imported for the interfaces
	// The interfaces below define the contract.
	// You import them if you need to use concrete types or functions
	// from these packages within THIS handler package, but for the handler
	// struct's dependencies, using the interfaces is preferred.
	// We keep them here in case other parts of your handler use them.
)

// KeyService defines the interface for key generation operations.
// The concrete implementation (e.g., `*keyservice.KeyService` from your `internal/keyservice` package)
// must satisfy this interface. If its methods use pointer receivers, then the concrete instance
// passed to NewHTTPHandler must be a pointer.
type KeyService interface {
	GenerateKey(length int) (string, error)
	// Add other KeyService methods here if your handlers use them
}

// MetricsService defines the interface for recording application metrics.
// The concrete implementation (e.g., `*metrics.PrometheusMetrics` from your `internal/metrics` package)
// must satisfy this interface.
type MetricsService interface {
	RecordKeyGeneration(length int, success bool)
	// RecordHealthCheck() // Uncomment if you add a specific metric for health checks
}

// HTTPHandler holds the dependencies required by your HTTP request handlers.
// Its fields are the *interface types* defined above, not concrete service types.
type HTTPHandler struct {
	keyService KeyService
	metricsSvc MetricsService
}

// NewHTTPHandler creates and returns a new instance of HTTPHandler.
// It accepts parameters of the *interface types* defined within this package.
// The calling code (your main.go) is responsible for providing concrete instances
// that implement these interfaces.
// This is the correct way for dependency injection.
func NewHTTPHandler(ks KeyService, ms MetricsService) *HTTPHandler {
	return &HTTPHandler{
		keyService: ks,
		metricsSvc: ms,
	}
}

// HealthCheck handles requests to the /health endpoint.
func (h *HTTPHandler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	// In a more complex app, you might check core dependencies here.
	w.WriteHeader(http.StatusOK)
	_, err := w.Write([]byte("Healthy"))
	if err != nil {
		log.Printf("Error writing health check response: %v", err)
	}
}

// ReadinessCheck handles requests to the /ready endpoint.
// This is the handler for the Kubernetes readiness probe.
func (h *HTTPHandler) ReadinessCheck(w http.ResponseWriter, r *http.Request) {
	// For a memory-based key server, simply being able to respond means it's ready.
	w.WriteHeader(http.StatusOK)
	_, err := w.Write([]byte("Ready to serve traffic!"))
	if err != nil {
		log.Printf("Error writing readiness response: %v", err)
	}
}

// GenerateKey handles requests to generate a key of a specified length.
func (h *HTTPHandler) GenerateKey(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	lengthStr := vars["length"]

	length, err := strconv.Atoi(lengthStr)
	if err != nil {
		http.Error(w, "Invalid key length. Must be a positive integer.", http.StatusBadRequest)
		h.metricsSvc.RecordKeyGeneration(0, false)
		return
	}

	if length <= 0 {
		http.Error(w, "Key length must be a positive integer.", http.StatusBadRequest)
		h.metricsSvc.RecordKeyGeneration(length, false)
		return
	}

	key, err := h.keyService.GenerateKey(length)
	if err != nil {
		log.Printf("Error generating key for length %d: %v", length, err)
		http.Error(w, fmt.Sprintf("Failed to generate key: %v", err), http.StatusInternalServerError)
		h.metricsSvc.RecordKeyGeneration(length, false)
		return
	}

	response := map[string]string{"key": key}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding key response: %v", err)
	}
	h.metricsSvc.RecordKeyGeneration(length, true)
}
