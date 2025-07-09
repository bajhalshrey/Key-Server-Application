package keygenerator_test

import (
	"encoding/base64"
	"testing"

	"github.com/bajhalshrey/Key-Server-Application/internal/keygenerator"
)

func TestCryptoKeyGenerator_Generate(t *testing.T) {
	generator := keygenerator.NewCryptoKeyGenerator()

	tests := []struct {
		name    string
		length  int
		wantErr bool
		wantLen int
	}{
		{"Generate 16 bytes", 16, false, 16},
		{"Generate 32 bytes", 32, false, 32},
		{"Generate 64 bytes", 64, false, 64},
		{"Generate 1 byte", 1, false, 1},
		{"Generate 1024 bytes", 1024, false, 1024},
		{"Generate 0 bytes", 0, true, 0},         // Expect error for 0
		{"Generate negative bytes", -5, true, 0}, // Expect error for negative
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			key, err := generator.Generate(tt.length)

			if (err != nil) != tt.wantErr {
				t.Errorf("Generate() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if tt.wantErr {
				if key != nil {
					t.Errorf("Generate() for error case returned non-nil key: %v", key)
				}
				return
			}

			// For successful generations:
			if key == nil {
				t.Errorf("Generate() returned nil key, expected a byte slice")
				return
			}
			if len(key) != tt.wantLen {
				t.Errorf("Generate() generated key of length %d, want %d", len(key), tt.wantLen)
			}

			// Ensure the key is not empty (for valid lengths)
			if tt.wantLen > 0 && len(key) == 0 {
				t.Errorf("Generate() returned an empty key for length %d", tt.wantLen)
			}

			// Optional: Try to decode it to confirm it's valid base64 (if you were planning to encode it later)
			// This part is for conceptual validation; the generator returns raw bytes.
			// If you really want to check base64 validity, you'd need to encode it first.
			encodedKey := base64.URLEncoding.EncodeToString(key) // Encode the []byte to string
			decodedKey, decodeErr := base64.URLEncoding.DecodeString(encodedKey)
			if decodeErr != nil {
				t.Errorf("Failed to decode generated key as base64: %v", decodeErr)
			}
			if len(decodedKey) != len(key) {
				t.Errorf("Decoded key length %d does not match original key length %d", len(decodedKey), len(key))
			}
		})
	}
}
