// internal/keygenerator/keygenerator.go
package keygenerator

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
)

// CryptoKeyGenerator defines the interface for key generation.
type CryptoKeyGenerator interface {
	Generate(length int) (string, error)
}

// cryptoKeyGenerator implements CryptoKeyGenerator using crypto/rand.
type cryptoKeyGenerator struct{}

// NewCryptoKeyGenerator creates a new instance of cryptoKeyGenerator.
func NewCryptoKeyGenerator() CryptoKeyGenerator {
	return &cryptoKeyGenerator{}
}

// Generate creates a cryptographically secure random key of the specified length (in bytes).
// The key is returned as a base64 URL-encoded string.
func (g *cryptoKeyGenerator) Generate(length int) (string, error) {
	if length <= 0 {
		return "", fmt.Errorf("key length must be positive, got %d", length)
	}

	keyBytes := make([]byte, length)
	_, err := rand.Read(keyBytes)
	if err != nil {
		return "", fmt.Errorf("failed to read random bytes for key generation: %w", err)
	}

	// Return the key as a base64 URL-encoded string to ensure it's web-safe
	return base64.URLEncoding.EncodeToString(keyBytes), nil
}
