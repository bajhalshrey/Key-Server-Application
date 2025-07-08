package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds the application's configuration.
type Config struct {
	Port    string // Port for the HTTP server to listen on (e.g., "8080")
	MaxSize int    // Maximum key size allowed
	// Add other configuration fields as needed (e.g., TLS cert paths if dynamic)
}

// NewConfig loads configuration from environment variables or provides defaults.
func NewConfig() (*Config, error) {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080" // Default port
	}

	maxSizeStr := os.Getenv("MAX_KEY_SIZE")
	maxSize := 1024 // Default max key size
	if maxSizeStr != "" {
		parsedSize, err := strconv.Atoi(maxSizeStr)
		if err != nil {
			return nil, fmt.Errorf("invalid MAX_KEY_SIZE environment variable: %w", err)
		}
		if parsedSize <= 0 {
			return nil, fmt.Errorf("MAX_KEY_SIZE must be a positive integer")
		}
		maxSize = parsedSize
	}

	return &Config{
		Port:    port,
		MaxSize: maxSize,
	}, nil
}
