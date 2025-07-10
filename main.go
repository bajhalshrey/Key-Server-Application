package main

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/bajhalshrey/Key-Server-Application/internal/config"
	"github.com/bajhalshrey/Key-Server-Application/internal/handler"
	"github.com/bajhalshrey/Key-Server-Application/internal/keygenerator"
	"github.com/bajhalshrey/Key-Server-Application/internal/keyservice"
	"github.com/bajhalshrey/Key-Server-Application/internal/metrics"
)

// Application holds the application's dependencies and configuration.
type Application struct {
	config          *config.Config
	handler         *handler.HTTPHandler
	router          *mux.Router
	server          *http.Server
	metricsRegistry *prometheus.Registry
}

// NewApplication creates and initializes a new Application instance.
// It wires up all the dependencies (metrics, key generator, key service, handler).
func NewApplication(cfg *config.Config) *Application {
	appRegistry := prometheus.NewRegistry()
	appMetrics := metrics.NewPrometheusMetricsWithRegistry(appRegistry, cfg.MaxSize)

	keyGen := keygenerator.NewCryptoKeyGenerator()
	keySvc := keyservice.NewKeyService(keyGen, cfg, appMetrics)
	httpHandler := handler.NewHTTPHandler(keySvc, appMetrics)

	router := mux.NewRouter()

	app := &Application{
		config:          cfg,
		handler:         httpHandler,
		router:          router,
		metricsRegistry: appRegistry,
	}

	// Use %s for Addr as cfg.Port is a string (e.g., "8443")
	app.server = &http.Server{
		Addr:         fmt.Sprintf(":%s", app.config.Port), // FIX: Changed %d to %s
		Handler:      app.router,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	return app
}

// setupRoutes configures the HTTP routes for the application.
func (app *Application) setupRoutes() {
	app.router.HandleFunc("/health", app.handler.HealthCheck).Methods("GET")
	app.router.HandleFunc("/key/{length}", app.handler.GenerateKey).Methods("GET")
	app.router.HandleFunc("/ready", app.handler.ReadinessCheck).Methods("GET")
	app.router.Handle("/metrics", promhttp.HandlerFor(app.metricsRegistry, promhttp.HandlerOpts{})).Methods("GET")

	log.Println("Configured Routes:")
	err := app.router.Walk(func(route *mux.Route, router *mux.Router, ancestors []*mux.Route) error {
		path, err := route.GetPathTemplate()
		if err == nil {
			methods, _ := route.GetMethods()
			if methods == nil || len(methods) == 0 {
				log.Printf("  [ANY] %s", path)
			} else {
				log.Printf("  [%s] %s", strings.Join(methods, ", "), path)
			}
		}
		return nil
	})
	if err != nil {
		log.Printf("Error walking routes: %v", err)
	}
}

// Start runs the application, setting up routes and starting the HTTP server.
func (app *Application) Start() {
	app.setupRoutes()

	var cert *tls.Certificate
	if app.config.CertFile != "" && app.config.KeyFile != "" {
		loadedCert, err := tls.LoadX509KeyPair(app.config.CertFile, app.config.KeyFile)
		if err != nil {
			log.Fatalf("Error loading SSL certificates from %s and %s: %v", app.config.CertFile, app.config.KeyFile, err)
		}
		cert = &loadedCert
		log.Printf("Loaded TLS certificates: %s, %s", app.config.CertFile, app.config.KeyFile)
	} else {
		log.Println("TLS certificates not provided. Server will not run with HTTPS.")
	}

	tlsConfig := &tls.Config{
		MinVersion:               tls.VersionTLS12,
		PreferServerCipherSuites: true,
		CurvePreferences: []tls.CurveID{
			tls.CurveP521,
			tls.CurveP384,
			tls.CurveP256,
		},
		CipherSuites: []uint16{
			tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
			tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
			tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_AES_256_GCM_SHA384,
		},
	}
	if cert != nil {
		tlsConfig.Certificates = []tls.Certificate{*cert}
		app.server.TLSConfig = tlsConfig
	}

	go func() {
		var serveErr error
		if cert != nil {
			// FIX: Changed %d to %s for logging port
			log.Printf("Key Server starting on HTTPS port %s...", app.config.Port)
			serveErr = app.server.ListenAndServeTLS(app.config.CertFile, app.config.KeyFile)
		} else {
			// FIX: Changed %d to %s for logging port
			log.Printf("Key Server starting on HTTP port %s (TLS disabled)...", app.config.Port)
			serveErr = app.server.ListenAndServe()
		}

		if serveErr != nil && !errors.Is(serveErr, http.ErrServerClosed) {
			log.Fatalf("Server failed to start: %v", serveErr)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := app.server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited gracefully.")
}

func main() {
	cfg, err := config.NewConfig()
	if err != nil {
		log.Fatalf("Error loading configuration: %v", err)
	}

	app := NewApplication(cfg)
	app.Start()
}
