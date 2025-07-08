// application.go
package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
	"github.com/bajhalshrey/Key-Server-Application/internal/handler"
	"github.com/bajhalshrey/Key-Server-Application/internal/keygenerator"
	"github.com/bajhalshrey/Key-Server-Application/internal/keyservice"
	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
)

// Application holds the application's dependencies and configuration.
type Application struct {
	config  *config.Config
	handler *handler.HTTPHandler // Use the specific HTTPHandler struct
}

// NewApplication creates and initializes a new Application instance.
// It wires up all the dependencies (metrics, key generator, key service, handler).
func NewApplication(cfg *config.Config) *Application { // FIX: Only takes config as argument
	// Initialize Prometheus metrics service first
	// Use metrics.DefaultRegistry for the main application
	promMetrics := metrics.NewPrometheusMetricsWithRegistry(metrics.DefaultRegistry, cfg.MaxSize)

	// Initialize the cryptographic key generator
	keyGen := keygenerator.NewCryptoKeyGenerator()

	// Initialize the key service with the generator, config, and metrics
	keySvc := keyservice.NewKeyService(keyGen, cfg, promMetrics)

	// Initialize the HTTP handler with the key service and metrics
	httpHandler := handler.NewHTTPHandler(keySvc, promMetrics)

	return &Application{
		config:  cfg,
		handler: httpHandler,
	}
}

// setupRoutes configures the HTTP routes for the application.
func (app *Application) setupRoutes() {
	// Use the correct method names from handler.HTTPHandler
	http.HandleFunc("/key/", app.handler.GenerateKey)   // Corrected method name
	http.HandleFunc("/health", app.handler.HealthCheck) // Corrected method name
	// Expose Prometheus metrics on /metrics endpoint
	http.Handle("/metrics", promhttp.Handler()) // Standard Prometheus handler
	log.Println("Routes configured: /key/{length}, /health, /metrics")
}

// Start runs the application, setting up routes and starting the HTTP server.
// This method was previously named Run() in your main.go.
func (app *Application) Start() { // FIX: Renamed from Run()
	app.setupRoutes()

	// Setup TLS configuration
	tlsConfig := &tls.Config{
		MinVersion:               tls.VersionTLS12,
		CurvePreferences:         []tls.CurveID{tls.CurveP521, tls.CurveP384, tls.CurveP256},
		PreferServerCipherSuites: true,
		CipherSuites: []uint16{
			tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,
			tls.TLS_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_RSA_WITH_AES_256_CBC_SHA,
		},
	}

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", app.config.Port), // Use config.Port
		TLSConfig:    tlsConfig,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
		// ErrorLog:     log.New(os.Stderr, "HTTP_SERVER_ERROR: ", log.LstdFlags), // Optional: dedicated error log
	}

	// Start server in a goroutine so it doesn't block the main thread
	go func() {
		log.Printf("Key Server starting on HTTPS port %s...", app.config.Port)
		if err := srv.ListenAndServeTLS("server.crt", "server.key"); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Could not listen on port %s: %v\n", app.config.Port, err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit // Block until a signal is received

	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited cleanly.")
}

// main function removed from here. It is now only in main.go
