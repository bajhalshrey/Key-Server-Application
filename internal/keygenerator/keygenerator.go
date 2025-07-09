package keygenerator

import (
	"crypto/rand"
	"fmt"
)

// CryptoKeyGenerator defines the interface for cryptographic key generation.
type CryptoKeyGenerator interface {
	Generate(length int) ([]byte, error) // Returns []byte, error
}

// cryptoKeyGenerator implements the CryptoKeyGenerator interface.
type cryptoKeyGenerator struct{}

// NewCryptoKeyGenerator creates a new instance of CryptoKeyGenerator.
func NewCryptoKeyGenerator() CryptoKeyGenerator {
	return &cryptoKeyGenerator{}
}

// Generate generates a cryptographically secure random byte slice of the specified length.
func (g *cryptoKeyGenerator) Generate(length int) ([]byte, error) { // Returns []byte, error
	if length <= 0 {
		return nil, fmt.Errorf("key length must be a positive integer")
	}

	key := make([]byte, length)
	_, err := rand.Read(key)
	if err != nil {
		return nil, fmt.Errorf("failed to read random bytes: %w", err)
	}
	return key, nil
}
