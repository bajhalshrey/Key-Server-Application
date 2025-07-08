// internal/keyservice/service_test.go
package keyservice_test

import (
	"errors"
	"testing"

	"github.com/prometheus/client_golang/prometheus"

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
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

// MockPrometheusMetrics (not directly used by NewKeyService in this setup, kept for reference)
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

func TestKeyService_GenerateKey(t *testing.T) {
	mockGen := &MockKeyGenerator{
		GenerateFunc: func(length int) (string, error) {
			if length == 16 {
				return "mocked_key_16bytes", nil
			}
			// This is the base error returned by the mock generator
			return "", errors.New("unsupported length")
		},
	}

	mockConfig := &config.Config{
		MaxSize: 1024,
	}

	metricsSvcForService := metrics.NewPrometheusMetricsWithRegistry(prometheus.NewRegistry(), mockConfig.MaxSize)
	keySvc := keyservice.NewKeyService(mockGen, mockConfig, metricsSvcForService)

	// Test case 1: Successful key generation
	key, err := keySvc.GenerateKey(16)
	if err != nil {
		t.Fatalf("GenerateKey returned an unexpected error: %v", err)
	}
	if key != "mocked_key_16bytes" {
		t.Errorf("Expected key 'mocked_key_16bytes', got '%s'", key)
	}

	// Test case 2: Key generation with unsupported length (from mock)
	_, err = keySvc.GenerateKey(32) // This length will cause mockGen.Generate to return "unsupported length"
	if err == nil {
		t.Error("Expected an error for unsupported length, got nil")
	}

	// FIX: Check for the full error string that the KeyService wraps.
	// If KeyService.GenerateKey wraps the error from keyGenerator like
	// `return "", fmt.Errorf("failed to generate key: %w", err)`,
	// then the final error string will be "failed to generate key: unsupported length".
	expectedErrorString := "failed to generate key: unsupported length"
	if err.Error() != expectedErrorString {
		t.Errorf("Expected error '%s', got '%v'", expectedErrorString, err)
	}

	// Alternative (more robust if you want to check the *underlying* error):
	// if !errors.Is(err, errors.New("unsupported length")) {
	//     t.Errorf("Expected underlying error 'unsupported length', got '%v'", err)
	// }
}
