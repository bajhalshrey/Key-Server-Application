package handler

import (
	// Still needed for potential JSON handling in other tests or future extensions
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
	"github.com/bajhalshrey/Key-Server-Application/internal/keyservice"
	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
	"github.com/prometheus/client_golang/prometheus"
)

// MockKeyService to simulate keyservice.KeyService for testing.
type MockKeyService struct {
	GenerateKeyFunc func(length int) (string, error)
}

// GenerateKey implements the keyservice.KeyService interface for the mock.
func (m *MockKeyService) GenerateKey(length int) (string, error) {
	if m.GenerateKeyFunc != nil {
		return m.GenerateKeyFunc(length)
	}
	// Default mock behavior: return a dummy encoded string for valid lengths.
	return keyservice.EncodeKey(make([]byte, length)), nil
}

// TestHTTPHandler_HealthCheck tests the /health endpoint.
func TestHTTPHandler_HealthCheck(t *testing.T) {
	mockKeyService := &MockKeyService{}
	registry := prometheus.NewRegistry()

	h := NewHTTPHandler(mockKeyService, metrics.NewPrometheusMetricsWithRegistry(registry, 1024)) // Pass directly.

	req, err := http.NewRequest("GET", "/health", nil)
	if err != nil {
		t.Fatalf("Could not create request: %v", err)
	}

	rr := httptest.NewRecorder()
	h.HealthCheck(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	expected := "Healthy"
	if rr.Body.String() != expected {
		t.Errorf("handler returned unexpected body: got %q want %q",
			rr.Body.String(), expected)
	}
}

// TestHTTPHandler_GenerateKey tests the /key/{length} endpoint.
func TestHTTPHandler_GenerateKey(t *testing.T) {
	dummyCfg := &config.Config{MaxSize: 1024}

	tests := []struct {
		name           string
		keyLength      string
		mockGenKeyFunc func(length int) (string, error)
		expectedStatus int
		expectedBody   string
	}{
		{
			name:      "Valid Key Length 32",
			keyLength: "32",
			mockGenKeyFunc: func(length int) (string, error) {
				return keyservice.EncodeKey(make([]byte, length)), nil
			},
			expectedStatus: http.StatusOK,
			expectedBody:   "{\"key\":\"" + keyservice.EncodeKey(make([]byte, 32)) + "\"}\n",
		},
		{
			name:      "Valid Key Length 1",
			keyLength: "1",
			mockGenKeyFunc: func(length int) (string, error) {
				return keyservice.EncodeKey(make([]byte, length)), nil
			},
			expectedStatus: http.StatusOK,
			expectedBody:   "{\"key\":\"" + keyservice.EncodeKey(make([]byte, 1)) + "\"}\n",
		},
		{
			name:           "Invalid Key Length - Non-integer",
			keyLength:      "abc",
			mockGenKeyFunc: func(length int) (string, error) { return "", nil }, // This mock won't be called, handler catches parsing error.
			expectedStatus: http.StatusBadRequest,
			expectedBody:   "Invalid key length. Must be a positive integer.\n\n", // Adjusted for double newline
		},
		{
			name:      "Invalid Key Length - Negative",
			keyLength: "-10",
			mockGenKeyFunc: func(length int) (string, error) {
				// Simulate the error from keyservice.GenerateKey.
				return "", fmt.Errorf("key length %d is out of allowed range (1-%d)", length, dummyCfg.MaxSize)
			},
			expectedStatus: http.StatusBadRequest,
			// Expected body now matches the output: "error message\n\n"
			expectedBody: "key length -10 is out of allowed range (1-" + strconv.Itoa(dummyCfg.MaxSize) + ")\n\n",
		},
		{
			name:      "Key Length - Zero",
			keyLength: "0",
			mockGenKeyFunc: func(length int) (string, error) {
				// Simulate the error from keyservice.GenerateKey.
				return "", fmt.Errorf("key length %d is out of allowed range (1-%d)", length, dummyCfg.MaxSize)
			},
			expectedStatus: http.StatusBadRequest,
			// Expected body now matches the output: "error message\n\n"
			expectedBody: "key length 0 is out of allowed range (1-" + strconv.Itoa(dummyCfg.MaxSize) + ")\n\n",
		},
		{
			name:      "Key Length - Exceeds MaxSize",
			keyLength: strconv.Itoa(dummyCfg.MaxSize + 1),
			mockGenKeyFunc: func(length int) (string, error) {
				// Simulate the error from keyservice.GenerateKey.
				return "", fmt.Errorf("key length %d is out of allowed range (1-%d)", length, dummyCfg.MaxSize)
			},
			expectedStatus: http.StatusBadRequest,
			// Expected body now matches the output: "error message\n\n"
			expectedBody: "key length " + strconv.Itoa(dummyCfg.MaxSize+1) + " is out of allowed range (1-" + strconv.Itoa(dummyCfg.MaxSize) + ")\n\n",
		},
		{
			name:      "Key Service Error",
			keyLength: "16",
			mockGenKeyFunc: func(length int) (string, error) {
				return "", errors.New("mock service error")
			},
			expectedStatus: http.StatusInternalServerError,
			expectedBody:   "Internal server error: Failed to generate key.\n\n", // Adjusted for double newline
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockKeyService := &MockKeyService{GenerateKeyFunc: tt.mockGenKeyFunc}
			testRegistry := prometheus.NewRegistry()
			testPromMetrics := metrics.NewPrometheusMetricsWithRegistry(testRegistry, dummyCfg.MaxSize)

			h := NewHTTPHandler(mockKeyService, testPromMetrics)

			req, err := http.NewRequest("GET", "/key/"+tt.keyLength, nil)
			if err != nil {
				t.Fatalf("Could not create request: %v", err)
			}

			rr := httptest.NewRecorder()
			h.GenerateKey(rr, req)

			if status := rr.Code; status != tt.expectedStatus {
				t.Errorf("handler returned wrong status code: got %v want %v",
					status, tt.expectedStatus)
			}

			bodyBytes, _ := ioutil.ReadAll(rr.Body)
			bodyString := string(bodyBytes)

			if bodyString != tt.expectedBody { // Changed to direct comparison
				t.Errorf("handler returned unexpected body for %s:\ngot %q\nwant %q",
					tt.name, bodyString, tt.expectedBody)
			}
		})
	}
}

// TestHTTPHandler_ReadinessCheck tests the /ready endpoint.
func TestHTTPHandler_ReadinessCheck(t *testing.T) {
	mockKeyService := &MockKeyService{}
	registry := prometheus.NewRegistry()
	promMetrics := metrics.NewPrometheusMetricsWithRegistry(registry, 1024)

	h := NewHTTPHandler(mockKeyService, promMetrics)

	req, err := http.NewRequest("GET", "/ready", nil)
	if err != nil {
		t.Fatalf("Could not create request: %v", err)
	}

	rr := httptest.NewRecorder()
	h.ReadinessCheck(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	expected := "Ready to serve traffic!"
	if rr.Body.String() != expected {
		t.Errorf("handler returned unexpected body: got %q want %q",
			rr.Body.String(), expected)
	}
}
