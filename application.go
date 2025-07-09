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

	"github.com/prometheus/client_golang/prometheus"

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
	"github.com/bajhalshrey/Key-Server-Application/internal/handler"
	"github.com/bajhalshrey/Key-Server-Application/internal/keygenerator"
	"github.com/bajhalshrey/Key-Server-Application/internal/keyservice"
	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
)

// Application holds the application's dependencies and configuration.
type Application struct {
	config  *config.Config
	handler *handler.HTTPHandler
	router  *http.ServeMux // Application manages its own ServeMux
	server  *http.Server   // Application manages its own HTTP server instance
}

// NewApplication creates and initializes a new Application instance.
// It wires up all the dependencies (metrics, key generator, key service, handler).
func NewApplication(cfg *config.Config) *Application {
	// Initialize Prometheus Registry and Metrics
	appRegistry := prometheus.NewRegistry() // Create a new Registry
	appMetrics := metrics.NewPrometheusMetricsWithRegistry(appRegistry, cfg.MaxSize)

	keyGen := keygenerator.NewCryptoKeyGenerator()
	keySvc := keyservice.NewKeyService(keyGen, cfg, appMetrics) // Pass appMetrics to service
	httpHandler := handler.NewHTTPHandler(keySvc, appMetrics)   // Pass appMetrics to handler

	// Create a new ServeMux for this application instance
	router := http.NewServeMux()

	return &Application{
		config:  cfg,
		handler: httpHandler,
		router:  router, // Assign the new router
		server: &http.Server{ // Initialize the server here
			Addr: fmt.Sprintf(":%s", cfg.Port),
			// Handler will be set in setupRoutes
			ReadTimeout:  5 * time.Second,
			WriteTimeout: 10 * time.Second,
			IdleTimeout:  120 * time.Second,
		},
	}
}

// setupRoutes configures the HTTP routes for the application.
func (app *Application) setupRoutes() {
	// Register handlers on the application's own router
	app.router.HandleFunc("/key/", app.handler.GenerateKey)
	app.router.HandleFunc("/health", app.handler.HealthCheck)
	app.router.HandleFunc("/ready", app.handler.ReadinessCheck)
	app.router.Handle("/metrics", app.handler.MetricsHandler()) // Use handler's MetricsHandler, which uses its own registry
	log.Println("Routes configured: /key/{length}, /health, /ready, /metrics")
}

// Start runs the application, setting up routes and starting the HTTP server.
func (app *Application) Start() {
	app.setupRoutes() // Configure routes on app.router

	app.server.Handler = app.router // Assign the router to the server

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
	app.server.TLSConfig = tlsConfig // Assign TLS config to the server

	// Start server in a goroutine
	go func() {
		log.Printf("Key Server starting on HTTPS port %s...", app.config.Port)
		var serveErr error
		// Check if cert and key files exist before trying to listen
		if _, err := os.Stat(app.config.CertFile); os.IsNotExist(err) {
			log.Fatalf("TLS certificate file not found: %s", app.config.CertFile)
		}
		if _, err := os.Stat(app.config.KeyFile); os.IsNotExist(err) {
			log.Fatalf("TLS key file not found: %s", app.config.KeyFile)
		}
		serveErr = app.server.ListenAndServeTLS(app.config.CertFile, app.config.KeyFile) // Use config paths

		if serveErr != nil && serveErr != http.ErrServerClosed {
			log.Fatalf("Server failed to start: %v", serveErr)
		}
	}()

	// Handle graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit // Block until a signal is received

	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := app.server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited cleanly.")
}
