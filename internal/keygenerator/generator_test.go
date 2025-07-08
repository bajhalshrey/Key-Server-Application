// internal/keygenerator/keygenerator_test.go
package keygenerator_test

import (
	"encoding/base64"
	"testing"

	"github.com/bajhalshrey/Key-Server-Application/internal/keygenerator"
)

func TestCryptoKeyGenerator_Generate(t *testing.T) {
	gen := keygenerator.NewCryptoKeyGenerator()

	testCases := []struct {
		name        string
		length      int
		expectErr   bool
		expectedLen int // Expected decoded byte length
	}{
		{"Generate 16 bytes", 16, false, 16},
		{"Generate 32 bytes", 32, false, 32},
		{"Generate 64 bytes", 64, false, 64},
		{"Generate 1 byte", 1, false, 1},
		{"Generate 1024 bytes", 1024, false, 1024},
		{"Generate 0 bytes", 0, true, 0},          // Should return error
		{"Generate negative bytes", -10, true, 0}, // Should return error
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			key, err := gen.Generate(tc.length)

			if tc.expectErr {
				if err == nil {
					t.Error("Expected an error but got none")
				}
				return // Test complete for error case
			}

			if err != nil {
				t.Fatalf("Unexpected error: %v", err)
			}
			if key == "" {
				t.Error("Generated key is empty")
			}

			// Decode the base64 string to check the original byte length
			decodedBytes, err := base64.URLEncoding.DecodeString(key)
			if err != nil {
				t.Fatalf("Failed to decode base64 key: %v", err)
			}
			if len(decodedBytes) != tc.expectedLen {
				t.Errorf("Expected decoded key length %d, got %d", tc.expectedLen, len(decodedBytes))
			}
		})
	}
}
