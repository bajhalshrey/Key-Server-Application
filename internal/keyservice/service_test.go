package keyservice_test

import (
	"encoding/base64" // <--- MOVED TO TOP
	"errors"
	"strings" // <--- MOVED TO TOP
	"testing"

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
	"github.com/bajhalshrey/Key-Server-Application/internal/keyservice"
	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
	"github.com/prometheus/client_golang/prometheus"
)

// MockKeyGenerator implements the CryptoKeyGenerator interface for testing.
type MockKeyGenerator struct {
	GenerateFunc func(length int) ([]byte, error)
}

// Generate implements the CryptoKeyGenerator interface.
func (m *MockKeyGenerator) Generate(length int) ([]byte, error) {
	if m.GenerateFunc != nil {
		return m.GenerateFunc(length)
	}
	return make([]byte, length), nil
}

func TestKeyService_GenerateKey(t *testing.T) {
	// Setup common mocks and configurations
	dummyConfig := &config.Config{MaxSize: 64}
	// Removed: registry := prometheus.NewRegistry() and mockMetrics := metrics.NewPrometheusMetricsWithRegistry(...)
	// These are now correctly initialized within each t.Run to ensure isolation.

	tests := []struct {
		name           string
		keyLength      int
		mockGen        *MockKeyGenerator
		expectedKey    string // Expected Base64 encoded string
		expectedErr    bool
		expectedErrMsg string
	}{
		{
			name:      "Valid Key Length",
			keyLength: 32,
			mockGen: &MockKeyGenerator{
				GenerateFunc: func(length int) ([]byte, error) {
					return make([]byte, length), nil // Return raw bytes
				},
			},
			expectedKey:    keyservice.EncodeKey(make([]byte, 32)), // Encode expected bytes
			expectedErr:    false,
			expectedErrMsg: "",
		},
		{
			name:      "Key Length Zero",
			keyLength: 0,
			mockGen: &MockKeyGenerator{
				GenerateFunc: func(length int) ([]byte, error) {
					return nil, nil // Should not be called, handled by service
				},
			},
			expectedKey:    "",
			expectedErr:    true,
			expectedErrMsg: "key length 0 is out of allowed range (1-64)",
		},
		{
			name:      "Key Length Exceeds Max Size",
			keyLength: 100, // > 64
			mockGen: &MockKeyGenerator{
				GenerateFunc: func(length int) ([]byte, error) {
					return nil, nil // Should not be called, handled by service
				},
			},
			expectedKey:    "",
			expectedErr:    true,
			expectedErrMsg: "key length 100 is out of allowed range (1-64)",
		},
		{
			name:      "Generator Returns Error",
			keyLength: 16,
			mockGen: &MockKeyGenerator{
				GenerateFunc: func(length int) ([]byte, error) {
					return nil, errors.New("mock generator error")
				},
			},
			expectedKey:    "",
			expectedErr:    true,
			expectedErrMsg: "failed to generate key: mock generator error",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Ensure a new KeyService and metrics are created for each test run to avoid state leakage
			currentRegistry := prometheus.NewRegistry()
			currentMetrics := metrics.NewPrometheusMetricsWithRegistry(currentRegistry, dummyConfig.MaxSize)
			service := keyservice.NewKeyService(tt.mockGen, dummyConfig, currentMetrics) // Pass mockMetrics here

			key, err := service.GenerateKey(tt.keyLength)

			if (err != nil) != tt.expectedErr {
				t.Errorf("GenerateKey() error = %v, expectedErr %v", err, tt.expectedErr)
				return
			}
			if tt.expectedErr {
				if err == nil || !strings.Contains(err.Error(), tt.expectedErrMsg) {
					t.Errorf("GenerateKey() expected error message %q, got %q", tt.expectedErrMsg, err.Error())
				}
				if key != "" {
					t.Errorf("GenerateKey() returned key %q for an error case, expected empty string", key)
				}
			} else {
				if key != tt.expectedKey {
					t.Errorf("GenerateKey() returned key %q, expected %q", key, tt.expectedKey)
				}
				// Optional: Decode and check length of the returned key to be extra sure
				decodedKey, decodeErr := base64.URLEncoding.DecodeString(key)
				if decodeErr != nil {
					t.Errorf("GenerateKey() returned non-base64 key: %v", decodeErr)
				}
				if len(decodedKey) != tt.keyLength {
					t.Errorf("GenerateKey() returned decoded key of length %d, expected %d", len(decodedKey), tt.keyLength)
				}
			}
		})
	}
}
