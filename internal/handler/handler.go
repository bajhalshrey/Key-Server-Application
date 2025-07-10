package handler

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"

	"github.com/bajhalshrey/Key-Server-Application/internal/keyservice"
	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
	"github.com/gorilla/mux"
)

// HTTPHandler handles HTTP requests for the key server.
type HTTPHandler struct {
	keyService keyservice.KeyService
	metricsSvc metrics.MetricsService
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
	fmt.Fprint(w, "Healthy") // No trailing "\n"
}

// ReadinessCheck handles the /ready endpoint.
func (h *HTTPHandler) ReadinessCheck(w http.ResponseWriter, r *http.Request) {
	h.metricsSvc.IncHTTPStatusCounter(http.StatusOK)
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "Ready to serve traffic!") // No trailing "\n"
}

// GenerateKey handles the /key/{length} endpoint.
func (h *HTTPHandler) GenerateKey(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	lengthStr := vars["length"]

	length, err := strconv.Atoi(lengthStr)
	if err != nil {
		// http.Error automatically adds a newline. The string should NOT end with "\n".
		http.Error(w, "Invalid key length. Must be a positive integer.", http.StatusBadRequest)
		h.metricsSvc.IncHTTPStatusCounter(http.StatusBadRequest)
		h.metricsSvc.RecordKeyGeneration(length, false)
		return
	}

	key, err := h.keyService.GenerateKey(length)
	if err != nil {
		// http.Error automatically adds a newline. The string should NOT end with "\n".
		if strings.Contains(err.Error(), "out of allowed range") {
			http.Error(w, err.Error(), http.StatusBadRequest)
			h.metricsSvc.IncHTTPStatusCounter(http.StatusBadRequest)
			h.metricsSvc.RecordKeyGeneration(length, false)
			return
		}
		// http.Error automatically adds a newline. The string should NOT end with "\n".
		http.Error(w, fmt.Sprintf("Internal server error: Failed to generate key."), http.StatusInternalServerError)
		h.metricsSvc.IncHTTPStatusCounter(http.StatusInternalServerError)
		h.metricsSvc.RecordKeyGeneration(length, false)
		return
	}

	// Successful JSON response
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	response := map[string]string{"key": key}
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding JSON response: %v", err)
	}

	h.metricsSvc.IncHTTPStatusCounter(http.StatusOK)
	h.metricsSvc.RecordKeyGeneration(length, true)
}
