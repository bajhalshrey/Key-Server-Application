package config_test

import (
	"os"
	"testing"

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
)

func TestNewConfig(t *testing.T) {
	// Clear all relevant environment variables before each test case
	clearEnv := func() {
		os.Unsetenv("PORT")
		os.Unsetenv("MAX_KEY_SIZE")
		os.Unsetenv("TLS_CERT_FILE")
		os.Unsetenv("TLS_KEY_FILE")
	}

	// Test case 1: Default values
	t.Run("Default Values", func(t *testing.T) {
		clearEnv()
		cfg, err := config.NewConfig() // 'err' is declared here using :=
		if err != nil {
			t.Fatalf("NewConfig returned an error for default values: %v", err)
		}
		if cfg.Port != "8443" {
			t.Errorf("Expected default Port '8443', got '%s'", cfg.Port)
		}
		if cfg.MaxSize != 1024 {
			t.Errorf("Expected default MaxSize 1024, got %d", cfg.MaxSize)
		}
		if cfg.CertFile != "/etc/key-server/tls/server.crt" {
			t.Errorf("Expected default CertFile '/etc/key-server/tls/server.crt', got '%s'", cfg.CertFile)
		}
		if cfg.KeyFile != "/etc/key-server/tls/server.key" {
			t.Errorf("Expected default KeyFile '/etc/key-server/tls/server.key', got '%s'", cfg.KeyFile)
		}
	})

	// Test case 2: Custom PORT
	t.Run("Custom PORT", func(t *testing.T) {
		clearEnv()
		os.Setenv("PORT", "9000")
		cfg, err := config.NewConfig() // 'err' is declared here using :=
		if err != nil {
			t.Fatalf("NewConfig returned an error for custom PORT: %v", err)
		}
		if cfg.Port != "9000" {
			t.Errorf("Expected custom Port '9000', got '%s'", cfg.Port)
		}
	})

	// Test case 3: Custom MAX_KEY_SIZE
	t.Run("Custom MAX_KEY_SIZE", func(t *testing.T) {
		clearEnv()
		os.Setenv("MAX_KEY_SIZE", "512")
		cfg, err := config.NewConfig() // 'err' is declared here using :=
		if err != nil {
			t.Fatalf("NewConfig returned an error for custom MAX_KEY_SIZE: %v", err)
		}
		if cfg.MaxSize != 512 {
			t.Errorf("Expected custom MaxSize 512, got %d", cfg.MaxSize)
		}
	})

	// Test case 4: Custom TLS_CERT_FILE and TLS_KEY_FILE
	t.Run("Custom TLS Files", func(t *testing.T) {
		clearEnv()
		os.Setenv("TLS_CERT_FILE", "/tmp/custom_cert.crt")
		os.Setenv("TLS_KEY_FILE", "/tmp/custom_key.key")
		cfg, err := config.NewConfig() // 'err' is declared here using :=
		if err != nil {
			t.Fatalf("NewConfig returned an error for custom TLS files: %v", err)
		}
		if cfg.CertFile != "/tmp/custom_cert.crt" {
			t.Errorf("Expected custom CertFile '/tmp/custom_cert.crt', got '%s'", cfg.CertFile)
		}
		if cfg.KeyFile != "/tmp/custom_key.key" {
			t.Errorf("Expected custom KeyFile '/tmp/custom_key.key', got '%s'", cfg.KeyFile)
		}
	})

	// Test case 5: Invalid MAX_KEY_SIZE
	t.Run("Invalid MAX_KEY_SIZE", func(t *testing.T) {
		clearEnv()
		os.Setenv("MAX_KEY_SIZE", "abc")
		_, err := config.NewConfig() // 'err' is declared here using :=
		if err == nil {
			t.Error("Expected an error for invalid MAX_KEY_SIZE, got nil")
		}
	})

	// Test case 6: Zero MAX_KEY_SIZE
	t.Run("Zero MAX_KEY_SIZE", func(t *testing.T) {
		clearEnv()
		os.Setenv("MAX_KEY_SIZE", "0")
		_, err := config.NewConfig() // 'err' is declared here using :=
		if err == nil {
			t.Error("Expected an error for zero MAX_KEY_SIZE, got nil")
		}
	})

	// Test case 7: Negative MAX_KEY_SIZE
	t.Run("Negative MAX_KEY_SIZE", func(t *testing.T) {
		clearEnv()
		os.Setenv("MAX_KEY_SIZE", "-100")
		_, err := config.NewConfig() // 'err' is declared here using :=
		if err == nil {
			t.Error("Expected an error for negative MAX_KEY_SIZE, got nil")
		}
	})
}
