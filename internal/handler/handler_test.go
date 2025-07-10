package handler_test

import (
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
	"github.com/bajhalshrey/Key-Server-Application/internal/handler"
	"github.com/bajhalshrey/Key-Server-Application/internal/keyservice" // Ensure this is imported
	"github.com/gorilla/mux"
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
	bytesNeeded := (length*3 + 3) / 4
	dummyBytes := make([]byte, bytesNeeded)
	for i := 0; i < bytesNeeded; i++ {
		dummyBytes[i] = byte(i % 256)
	}
	encoded := keyservice.EncodeKey(dummyBytes)
	if len(encoded) > length {
		encoded = encoded[:length]
	}
	return encoded, nil
}

// MockMetricsService implements metrics.MetricsService for testing.
type MockMetricsService struct {
	IncHTTPStatusCounterCalls []int
	RecordKeyGenerationCalls  []struct {
		Length  int
		Success bool
	}
}

func (m *MockMetricsService) IncHTTPStatusCounter(statusCode int) {
	m.IncHTTPStatusCounterCalls = append(m.IncHTTPStatusCounterCalls, statusCode)
}
func (m *MockMetricsService) RecordKeyGeneration(length int, success bool) {
	m.RecordKeyGenerationCalls = append(m.RecordKeyGenerationCalls, struct {
		Length  int
		Success bool
	}{length, success})
}
func (m *MockMetricsService) IncrementKeyGenerationRequests()                           {}
func (m *MockMetricsService) IncrementKeyGenerationErrors()                             {}
func (m *MockMetricsService) IncrementInvalidKeyLengthErrors()                          {}
func (m *MockMetricsService) ObserveKeyGenerationDuration(duration float64, length int) {}
func (m *MockMetricsService) ObserveKeyLength(length float64)                           {}
func (m *MockMetricsService) IncrementHTTPRequestsTotal(statusCode, path string)        {}

// MetricsHandler implements the MetricsService interface.
// It returns a dummy http.Handler for testing purposes.
func (m *MockMetricsService) MetricsHandler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// A no-op handler for the mock
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "Mock Metrics")
	})
}

// TestHTTPHandler_HealthCheck tests the /health endpoint.
func TestHTTPHandler_HealthCheck(t *testing.T) {
	mockKeyService := &MockKeyService{}
	mockMetrics := &MockMetricsService{} // Use mock metrics
	h := handler.NewHTTPHandler(mockKeyService, mockMetrics)

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

	expected := "Healthy" // No trailing newline
	if rr.Body.String() != expected {
		t.Errorf("handler returned unexpected body: got %q want %q",
			rr.Body.String(), expected)
	}

	if len(mockMetrics.IncHTTPStatusCounterCalls) != 1 || mockMetrics.IncHTTPStatusCounterCalls[0] != http.StatusOK {
		t.Errorf("Expected IncHTTPStatusCounter to be called once with %d, got %v", http.StatusOK, mockMetrics.IncHTTPStatusCounterCalls)
	}
}

// TestHTTPHandler_GenerateKey tests the /key/{length} endpoint.
func TestHTTPHandler_GenerateKey(t *testing.T) {
	dummyCfg := &config.Config{MaxSize: 1024}

	tests := []struct {
		name                string
		keyLength           string
		mockGenKeyFunc      func(length int) (string, error)
		expectedStatus      int
		expectedBody        string
		expectRecordKeyGen  bool
		recordKeyGenSuccess bool
	}{
		{
			name:      "Valid Key Length 32",
			keyLength: "32",
			mockGenKeyFunc: func(length int) (string, error) {
				bytesNeeded := (length*3 + 3) / 4
				return keyservice.EncodeKey(make([]byte, bytesNeeded))[:length], nil
			},
			expectedStatus: http.StatusOK,
			expectedBody: "{\"key\":\"" + (func() string {
				bytesNeeded := (32*3 + 3) / 4
				encoded := keyservice.EncodeKey(make([]byte, bytesNeeded))
				return encoded[:32]
			})() + "\"}\n",
			expectRecordKeyGen:  true,
			recordKeyGenSuccess: true,
		},
		{
			name:      "Valid Key Length 1",
			keyLength: "1",
			mockGenKeyFunc: func(length int) (string, error) {
				bytesNeeded := (length*3 + 3) / 4
				return keyservice.EncodeKey(make([]byte, bytesNeeded))[:length], nil
			},
			expectedStatus: http.StatusOK,
			expectedBody: "{\"key\":\"" + (func() string {
				bytesNeeded := (1*3 + 3) / 4
				encoded := keyservice.EncodeKey(make([]byte, bytesNeeded))
				return encoded[:1]
			})() + "\"}\n",
			expectRecordKeyGen:  true,
			recordKeyGenSuccess: true,
		},
		{
			name:                "Invalid Key Length - Non-integer",
			keyLength:           "abc",
			mockGenKeyFunc:      nil,
			expectedStatus:      http.StatusBadRequest,
			expectedBody:        "Invalid key length. Must be a positive integer.\n",
			expectRecordKeyGen:  true,
			recordKeyGenSuccess: false,
		},
		{
			name:      "Invalid Key Length - Negative",
			keyLength: "-10",
			mockGenKeyFunc: func(length int) (string, error) {
				return "", fmt.Errorf("key length %d is out of allowed range (1-%d)", length, dummyCfg.MaxSize)
			},
			expectedStatus:      http.StatusBadRequest,
			expectedBody:        "key length -10 is out of allowed range (1-" + strconv.Itoa(dummyCfg.MaxSize) + ")\n",
			expectRecordKeyGen:  true,
			recordKeyGenSuccess: false,
		},
		{
			name:      "Key Length - Zero",
			keyLength: "0",
			mockGenKeyFunc: func(length int) (string, error) {
				return "", fmt.Errorf("key length %d is out of allowed range (1-%d)", length, dummyCfg.MaxSize)
			},
			expectedStatus:      http.StatusBadRequest,
			expectedBody:        "key length 0 is out of allowed range (1-" + strconv.Itoa(dummyCfg.MaxSize) + ")\n",
			expectRecordKeyGen:  true,
			recordKeyGenSuccess: false,
		},
		{
			name:      "Key Length - Exceeds MaxSize",
			keyLength: strconv.Itoa(dummyCfg.MaxSize + 1),
			mockGenKeyFunc: func(length int) (string, error) {
				return "", fmt.Errorf("key length %d is out of allowed range (1-%d)", length, dummyCfg.MaxSize)
			},
			expectedStatus:      http.StatusBadRequest,
			expectedBody:        "key length " + strconv.Itoa(dummyCfg.MaxSize+1) + " is out of allowed range (1-" + strconv.Itoa(dummyCfg.MaxSize) + ")\n",
			expectRecordKeyGen:  true,
			recordKeyGenSuccess: false,
		},
		{
			name:      "Key Service Internal Error",
			keyLength: "16",
			mockGenKeyFunc: func(length int) (string, error) {
				return "", errors.New("mock internal service error")
			},
			expectedStatus:      http.StatusInternalServerError,
			expectedBody:        "Internal server error: Failed to generate key.\n",
			expectRecordKeyGen:  true,
			recordKeyGenSuccess: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockKeyService := &MockKeyService{GenerateKeyFunc: tt.mockGenKeyFunc}
			mockMetrics := &MockMetricsService{}
			h := handler.NewHTTPHandler(mockKeyService, mockMetrics)

			router := mux.NewRouter()
			router.HandleFunc("/key/{length}", h.GenerateKey).Methods("GET")

			req, err := http.NewRequest("GET", "/key/"+tt.keyLength, nil)
			if err != nil {
				t.Fatalf("Could not create request: %v", err)
			}

			rr := httptest.NewRecorder()
			router.ServeHTTP(rr, req)

			if status := rr.Code; status != tt.expectedStatus {
				t.Errorf("handler returned wrong status code: got %v want %v",
					status, tt.expectedStatus)
			}

			bodyBytes, _ := ioutil.ReadAll(rr.Body)
			bodyString := string(bodyBytes)

			if bodyString != tt.expectedBody {
				t.Errorf("handler returned unexpected body for %s:\ngot %q\nwant %q",
					tt.name, bodyString, tt.expectedBody)
			}

			if len(mockMetrics.IncHTTPStatusCounterCalls) != 1 || mockMetrics.IncHTTPStatusCounterCalls[0] != tt.expectedStatus {
				t.Errorf("Expected IncHTTPStatusCounter to be called once with %d, got %v", tt.expectedStatus, mockMetrics.IncHTTPStatusCounterCalls)
			}
			if tt.expectRecordKeyGen {
				if len(mockMetrics.RecordKeyGenerationCalls) != 1 ||
					mockMetrics.RecordKeyGenerationCalls[0].Length != func() int {
						l, _ := strconv.Atoi(tt.keyLength)
						return l
					}() ||
					mockMetrics.RecordKeyGenerationCalls[0].Success != tt.recordKeyGenSuccess {
					t.Errorf("Expected RecordKeyGeneration to be called once with length %s and success %t, got %v", tt.keyLength, tt.recordKeyGenSuccess, mockMetrics.RecordKeyGenerationCalls)
				}
			} else {
				if len(mockMetrics.RecordKeyGenerationCalls) != 0 {
					t.Errorf("Expected RecordKeyGeneration not to be called, but it was: %v", mockMetrics.RecordKeyGenerationCalls)
				}
			}
		})
	}
}

// TestHTTPHandler_ReadinessCheck tests the /ready endpoint.
func TestHTTPHandler_ReadinessCheck(t *testing.T) {
	mockKeyService := &MockKeyService{}
	mockMetrics := &MockMetricsService{}
	h := handler.NewHTTPHandler(mockKeyService, mockMetrics)

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

	expected := "Ready to serve traffic!" // No trailing newline
	if rr.Body.String() != expected {
		t.Errorf("handler returned unexpected body: got %q want %q",
			rr.Body.String(), expected)
	}

	if len(mockMetrics.IncHTTPStatusCounterCalls) != 1 || mockMetrics.IncHTTPStatusCounterCalls[0] != http.StatusOK {
		t.Errorf("Expected IncHTTPStatusCounter to be called once with %d, got %v", http.StatusOK, mockMetrics.IncHTTPStatusCounterCalls)
	}
}
