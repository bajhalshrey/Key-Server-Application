package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds the application's configuration.
type Config struct {
	Port     string // Port for the HTTP server to listen on (e.g., "8080" for HTTP, "8443" for HTTPS)
	MaxSize  int    // Maximum key size allowed
	CertFile string // Path to the TLS certificate file (e.g., /etc/key-server/tls/server.crt)
	KeyFile  string // Path to the TLS key file (e.g., /etc/key-server/tls/server.key)
}

// NewConfig loads configuration from environment variables or provides defaults.
func NewConfig() (*Config, error) {
	// --- Server Port Configuration ---
	// Uses "PORT" environment variable, defaults to "8443" for HTTPS
	port := os.Getenv("PORT")
	if port == "" {
		port = "8443" // Changed default to 8443 as we are setting up HTTPS
	}

	// --- Max Key Size Configuration ---
	// Uses "MAX_KEY_SIZE" environment variable, defaults to 1024
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

	// --- TLS Certificate File Paths Configuration ---
	// Uses "TLS_CERT_FILE" and "TLS_KEY_FILE" environment variables
	// Defaults to paths expected when mounted from Kubernetes Secret
	certFile := os.Getenv("TLS_CERT_FILE")
	if certFile == "" {
		certFile = "/etc/key-server/tls/server.crt" // Default path inside container for mounted secret
	}

	keyFile := os.Getenv("TLS_KEY_FILE")
	if keyFile == "" {
		keyFile = "/etc/key-server/tls/server.key" // Default path inside container for mounted secret
	}

	// --- Create and Return Config ---
	return &Config{
		Port:     port,
		MaxSize:  maxSize,
		CertFile: certFile, // New field initialized
		KeyFile:  keyFile,  // New field initialized
	}, nil
}
