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

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
	"github.com/bajhalshrey/Key-Server-Application/internal/handler"
	"github.com/bajhalshrey/Key-Server-Application/internal/keygenerator"
	"github.com/bajhalshrey/Key-Server-Application/internal/keyservice"
	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	// Load configuration
	cfg, err := config.NewConfig()
	if err != nil {
		log.Fatalf("Error loading configuration: %v", err)
	}

	// Initialize Prometheus metrics
	registry := prometheus.NewRegistry()
	metricsSvc := metrics.NewPrometheusMetricsWithRegistry(registry, cfg.MaxSize)

	// Initialize key generator and service
	keyGen := keygenerator.NewCryptoKeyGenerator()
	// keyService should be of type keyservice.KeyService (interface)
	keyService := keyservice.NewKeyService(keyGen, cfg, metricsSvc) // This will return the interface type

	// Setup HTTP router and handlers
	router := mux.NewRouter()
	// NewHTTPHandler expects keyservice.KeyService (interface) and metrics.MetricsService (interface)
	httpHandler := handler.NewHTTPHandler(keyService, metricsSvc)

	// Register routes
	router.HandleFunc("/health", httpHandler.HealthCheck).Methods("GET")
	log.Printf("Route configured: [GET] /health")

	router.HandleFunc("/key/{length}", httpHandler.GenerateKey).Methods("GET")
	log.Printf("Route configured: [GET] /key/{length}")

	router.HandleFunc("/ready", httpHandler.ReadinessCheck).Methods("GET")
	log.Printf("Route configured: [GET] /ready")

	// Register Prometheus metrics handler
	router.Handle("/metrics", promhttp.HandlerFor(registry, promhttp.HandlerOpts{})).Methods("GET")
	log.Printf("Route configured: [GET] /metrics")

	// Log all configured routes (using Walk is good)
	router.Walk(func(route *mux.Route, router *mux.Router, ancestors []*mux.Route) error {
		path, err := route.GetPathTemplate()
		if err == nil {
			methods, _ := route.GetMethods()
			if methods == nil {
				log.Printf("Route configured: %s (ANY method)", path)
			} else {
				log.Printf("Route configured: %s %s", methods, path)
			}
		}
		return nil
	})

	// Load SSL certificates
	// Ensure server.crt and server.key exist in the same directory as the executable,
	// or provide full paths.
	cert, err := tls.LoadX509KeyPair(cfg.CertFile, cfg.KeyFile)
	if err != nil {
		log.Fatalf("Error loading SSL certificates from %s and %s: %v", cfg.CertFile, cfg.KeyFile, err)
	}

	// Configure TLS
	tlsConfig := &tls.Config{
		Certificates: []tls.Certificate{cert},
		MinVersion:   tls.VersionTLS12,
		CipherSuites: []uint16{
			tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
			tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
			tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_AES_256_GCM_SHA384,
		},
	}

	// Create HTTP server
	server := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Port), // Use cfg.Port
		Handler:      router,                       // Use the mux router
		TLSConfig:    tlsConfig,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Setup graceful shutdown
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("Key Server starting on HTTPS port %s...", cfg.Port)
		if err := server.ListenAndServeTLS(cfg.CertFile, cfg.KeyFile); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Could not listen on port %s: %v", cfg.Port, err)
		}
	}()

	<-stop

	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server shutdown failed: %v", err)
	}

	log.Println("Server gracefully stopped.")
}
