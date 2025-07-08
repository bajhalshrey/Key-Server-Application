// internal/keyservice/service.go
package keyservice

import (
	"fmt"
	"time"

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
	"github.com/bajhalshrey/Key-Server-Application/internal/keygenerator"
	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
)

// KeyService provides methods for key-related operations.
type KeyService struct {
	keyGenerator keygenerator.CryptoKeyGenerator
	config       *config.Config
	metrics      *metrics.PrometheusMetrics // Use the concrete struct pointer
}

// NewKeyService creates and returns a new KeyService instance.
func NewKeyService(
	kg keygenerator.CryptoKeyGenerator,
	cfg *config.Config,
	m *metrics.PrometheusMetrics, // Accept concrete metrics struct pointer
) *KeyService {
	return &KeyService{
		keyGenerator: kg,
		config:       cfg,
		metrics:      m,
	}
}

// GenerateKey generates a new key of the specified length.
func (s *KeyService) GenerateKey(length int) (string, error) {
	if length <= 0 || length > s.config.MaxSize {
		return "", fmt.Errorf("key length %d is out of allowed range (1-%d)", length, s.config.MaxSize)
	}

	start := time.Now()
	key, err := s.keyGenerator.Generate(length)
	duration := time.Since(start).Seconds()

	// Observe key generation duration only if the generation was successful
	// (or you might observe it for all attempts and tag with success/failure)
	s.metrics.ObserveKeyGenerationDuration(duration, length)

	if err != nil {
		// Wrap the error from the key generator for more context
		return "", fmt.Errorf("failed to generate key: %w", err)
	}

	return key, nil
}
