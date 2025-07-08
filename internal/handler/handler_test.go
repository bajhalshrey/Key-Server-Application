// internal/handler/handler_test.go
package handler_test

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/prometheus/client_golang/prometheus"

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
	"github.com/bajhalshrey/Key-Server-Application/internal/handler"
	"github.com/bajhalshrey/Key-Server-Application/internal/keyservice"
	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
)

// Mock for keygenerator.CryptoKeyGenerator interface
type MockKeyGenerator struct {
	GenerateFunc func(length int) (string, error)
}

func (m *MockKeyGenerator) Generate(length int) (string, error) {
	return m.GenerateFunc(length)
}

// MockPrometheusMetrics (not directly used by NewHTTPHandler in this setup, kept for reference)
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

func TestHTTPHandler_HealthCheck(t *testing.T) {
	// Setup mocks and dependencies for keyservice
	mockGenForSvc := &MockKeyGenerator{
		GenerateFunc: func(length int) (string, error) { return "", nil }, // HealthCheck doesn't use keygen
	}
	mockConfigForSvc := &config.Config{MaxSize: 1024} // No SrvPort in config
	metricsSvcForService := metrics.NewPrometheusMetricsWithRegistry(prometheus.NewRegistry(), mockConfigForSvc.MaxSize)
	keySvcInstance := keyservice.NewKeyService(mockGenForSvc, mockConfigForSvc, metricsSvcForService)

	// Instantiate a real metrics.PrometheusMetrics struct for the handler itself
	metricsSvcForHandler := metrics.NewPrometheusMetricsWithRegistry(prometheus.NewRegistry(), mockConfigForSvc.MaxSize)

	// Create the HTTPHandler instance
	httpHandler := handler.NewHTTPHandler(keySvcInstance, metricsSvcForHandler)

	req, err := http.NewRequest("GET", "/health", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	// Call the method on the httpHandler instance
	httpHandler.HealthCheck(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}

	expectedBody := "OK"
	if rr.Body.String() != expectedBody {
		t.Errorf("handler returned unexpected body: got %v want %v",
			rr.Body.String(), expectedBody)
	}
}

func TestHTTPHandler_GenerateKey(t *testing.T) {
	// Setup mocks and dependencies for keyservice
	mockGenForSvc := &MockKeyGenerator{
		GenerateFunc: func(length int) (string, error) {
			if length == 32 {
				return "generated_key_32bytes_from_mock_svc", nil
			}
			return "", errors.New("invalid length for mock key generation")
		},
	}
	mockConfigForSvc := &config.Config{MaxSize: 1024}
	metricsSvcForService := metrics.NewPrometheusMetricsWithRegistry(prometheus.NewRegistry(), mockConfigForSvc.MaxSize)
	keySvcInstance := keyservice.NewKeyService(mockGenForSvc, mockConfigForSvc, metricsSvcForService)

	// Instantiate a real metrics.PrometheusMetrics struct for the handler
	metricsSvcForHandler := metrics.NewPrometheusMetricsWithRegistry(prometheus.NewRegistry(), mockConfigForSvc.MaxSize)

	// Create the HTTPHandler instance
	httpHandler := handler.NewHTTPHandler(keySvcInstance, metricsSvcForHandler)

	// Test case 1: Valid key generation request
	req, err := http.NewRequest("GET", "/key/32", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	// Call the method on the httpHandler instance
	httpHandler.GenerateKey(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code for valid request: got %v want %v",
			status, http.StatusOK)
	}

	// FIX: Add newline to expected JSON body, as json.Encoder typically adds one.
	expectedBody := `{"key":"generated_key_32bytes_from_mock_svc"}` + "\n"
	if rr.Body.String() != expectedBody {
		t.Errorf("handler returned unexpected body for valid request: got %q want %q",
			rr.Body.String(), expectedBody) // Use %q to show raw string with newlines/special chars
	}

	// Test case 2: Invalid key length (non-integer)
	req, err = http.NewRequest("GET", "/key/invalid", nil)
	if err != nil {
		t.Fatal(err)
	}
	rr = httptest.NewRecorder()
	// Call the method on the httpHandler instance
	httpHandler.GenerateKey(rr, req)
	if status := rr.Code; status != http.StatusBadRequest {
		t.Errorf("handler returned wrong status code for non-integer length: got %v want %v",
			status, http.StatusBadRequest)
	}

	// Test case 3: Key length out of bounds (e.g., 0)
	req, err = http.NewRequest("GET", "/key/0", nil)
	if err != nil {
		t.Fatal(err)
	}
	rr = httptest.NewRecorder()
	httpHandler.GenerateKey(rr, req)
	if status := rr.Code; status != http.StatusBadRequest {
		t.Errorf("handler returned wrong status code for 0 length: got %v want %v",
			status, http.StatusBadRequest)
	}

	// Test case 4: Key length out of bounds (e.g., > MaxSize, assuming MaxSize is 1024 in handler.go)
	req, err = http.NewRequest("GET", "/key/2000", nil)
	if err != nil {
		t.Fatal(err)
	}
	rr = httptest.NewRecorder()
	httpHandler.GenerateKey(rr, req)
	if status := rr.Code; status != http.StatusBadRequest {
		t.Errorf("handler returned wrong status code for too large length: got %v want %v",
			status, http.StatusBadRequest)
	}

	// Test case 5: Error from key service (e.g., mock returns error for specific length)
	mockGenForSvc.GenerateFunc = func(length int) (string, error) {
		if length == 10 {
			return "", errors.New("mocked key service error")
		}
		return "some_key", nil
	}
	req, err = http.NewRequest("GET", "/key/10", nil)
	if err != nil {
		t.Fatal(err)
	}
	rr = httptest.NewRecorder()
	httpHandler.GenerateKey(rr, req)
	if status := rr.Code; status != http.StatusInternalServerError {
		t.Errorf("handler returned wrong status code for key service error: got %v want %v",
			status, http.StatusInternalServerError)
	}
}
