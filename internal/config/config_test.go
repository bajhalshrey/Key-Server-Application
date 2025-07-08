// internal/config/config_test.go
package config_test

import (
	"os"
	"testing"

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
)

func TestNewConfig(t *testing.T) {
	// Clear environment variables before each test
	os.Unsetenv("PORT")
	os.Unsetenv("MAX_KEY_SIZE")

	// Test case 1: Default values
	cfg, err := config.NewConfig()
	if err != nil {
		t.Fatalf("NewConfig returned an error for default values: %v", err)
	}
	if cfg.Port != "8080" {
		t.Errorf("Expected default Port '8080', got '%s'", cfg.Port)
	}
	if cfg.MaxSize != 1024 {
		t.Errorf("Expected default MaxSize 1024, got %d", cfg.MaxSize)
	}

	// Test case 2: Custom PORT
	os.Setenv("PORT", "9000")
	cfg, err = config.NewConfig()
	if err != nil {
		t.Fatalf("NewConfig returned an error for custom PORT: %v", err)
	}
	if cfg.Port != "9000" {
		t.Errorf("Expected custom Port '9000', got '%s'", cfg.Port)
	}
	os.Unsetenv("PORT") // Clean up

	// Test case 3: Custom MAX_KEY_SIZE
	os.Setenv("MAX_KEY_SIZE", "512")
	cfg, err = config.NewConfig()
	if err != nil {
		t.Fatalf("NewConfig returned an error for custom MAX_KEY_SIZE: %v", err)
	}
	if cfg.MaxSize != 512 {
		t.Errorf("Expected custom MaxSize 512, got %d", cfg.MaxSize)
	}
	os.Unsetenv("MAX_KEY_SIZE") // Clean up

	// Test case 4: Invalid MAX_KEY_SIZE
	os.Setenv("MAX_KEY_SIZE", "abc")
	_, err = config.NewConfig()
	if err == nil {
		t.Error("Expected an error for invalid MAX_KEY_SIZE, got nil")
	}
	os.Unsetenv("MAX_KEY_SIZE") // Clean up

	// Test case 5: Zero MAX_KEY_SIZE
	os.Setenv("MAX_KEY_SIZE", "0")
	_, err = config.NewConfig()
	if err == nil {
		t.Error("Expected an error for zero MAX_KEY_SIZE, got nil")
	}
	os.Unsetenv("MAX_KEY_SIZE") // Clean up

	// Test case 6: Negative MAX_KEY_SIZE
	os.Setenv("MAX_KEY_SIZE", "-100")
	_, err = config.NewConfig()
	if err == nil {
		t.Error("Expected an error for negative MAX_KEY_SIZE, got nil")
	}
	os.Unsetenv("MAX_KEY_SIZE") // Clean up
}
