package main

import (
	"context"
	"crypto/tls"
	"flag"
	"hello-grpc/common"
	"hello-grpc/common/pb"
	"hello-grpc/conn"
	"hello-grpc/etcd/register"
	"hello-grpc/server/service"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"sync"
	"syscall"
	"time"

	"google.golang.org/grpc/keepalive"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

// Configuration constants
const (
	gracefulShutdownTimeout = 10 * time.Second
	metricsPort             = "9100"
	maxConnectionAgeSeconds = 30
	maxRequestsPerSecond    = 200
)

// Certificate file paths
var (
	certKeyPath   string
	certChainPath string
	rootCertPath  string
)

// Command-line flags
var (
	useTLS = flag.Bool("tls", false, "Enable TLS/SSL secure communication")
)

func init() {
	// Set up logging configuration
	log.SetFormatter(&log.TextFormatter{
		FullTimestamp:   true,
		TimestampFormat: "2006-01-02 15:04:05.000",
	})

	// Initialize certificate paths based on operating system
	// or environment variable if specified
	certBasePath := os.Getenv("CERT_BASE_PATH")
	if certBasePath == "" {
		// Use /var/hello_grpc base path for all OS (except Windows)
		osType := runtime.GOOS
		log.Infof("Operating System: %s", osType)

		switch osType {
		case "windows":
			certBasePath = filepath.Join("d:", "garden", "var", "hello_grpc", "server_certs")
		case "darwin": // macOS
			certBasePath = filepath.Join("/var", "hello_grpc", "server_certs")
		case "linux":
			certBasePath = filepath.Join("/var", "hello_grpc", "server_certs")
		default:
			log.Errorf("Unsupported operating system: %s", osType)
			certBasePath = filepath.Join("/var", "hello_grpc", "server_certs")
		}
	}

	// Set certificate file paths
	certKeyPath = filepath.Join(certBasePath, "private.key")
	certChainPath = filepath.Join(certBasePath, "full_chain.pem")
	rootCertPath = filepath.Join(certBasePath, "myssl_root.cer")

	log.Debugf("Certificate paths initialized: key=%s, chain=%s, root=%s",
		certKeyPath, certChainPath, rootCertPath)
}

func main() {
	// Parse command-line flags
	flag.Parse()

	// Create root context for managing the entire application lifecycle
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Get server address
	host := conn.GrpcServerHost()
	port := conn.GrpcServerPort()
	address := host + ":" + port

	// Create gRPC server with appropriate options
	server := createGrpcServer()

	// Initialize server implementation
	serviceImpl := createServiceImplementation(ctx)

	// Register service, health check and reflection
	pb.RegisterLandingServiceServer(server, &serviceImpl)
	healthServer := health.NewServer()
	healthServer.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(server, healthServer)
	reflection.Register(server)

	// Start listening on configured port
	log.Infof("Server address: %s", address)
	listener, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	// Setup metrics server if enabled
	if os.Getenv("GRPC_HELLO_METRICS") == "Y" {
		startMetricsServer(ctx)
	}

	// Setup service discovery
	etcdRegister := registerWithServiceDiscovery(ctx, address)
	if etcdRegister != nil {
		defer func() {
			if err := etcdRegister.Close(); err != nil {
				log.Errorf("Failed to close etcd register: %v", err)
			}
		}()
	}

	// Setup signal handling for graceful shutdown
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM, syscall.SIGINT)

	// Use WaitGroup to coordinate shutdown
	var wg sync.WaitGroup
	wg.Add(1)

	// Start server in a goroutine
	go func() {
		defer wg.Done()
		log.Infof("Starting gRPC server on port %s [version: %s]", port, common.GetVersion())

		if err := server.Serve(listener); err != nil {
			if err != grpc.ErrServerStopped {
				log.Fatalf("Failed to serve: %v", err)
			}
			log.Info("Server stopped serving")
		}
	}()

	// Wait for shutdown signal
	select {
	case <-ctx.Done():
		log.Info("Server shutting down due to context cancellation")
	case sig := <-shutdown:
		log.Infof("Server shutting down due to signal: %v", sig)
		cancel()
	}

	// Update health status to NOT_SERVING
	healthServer.SetServingStatus("", healthpb.HealthCheckResponse_NOT_SERVING)

	// Start graceful shutdown with timeout
	log.Info("Initiating graceful shutdown...")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), gracefulShutdownTimeout)
	defer shutdownCancel()

	// Create a channel to signal when the server has stopped gracefully
	stopped := make(chan struct{})
	go func() {
		server.GracefulStop()
		close(stopped)
	}()

	// Wait for graceful shutdown or timeout
	select {
	case <-shutdownCtx.Done():
		log.Warn("Graceful shutdown timed out, forcing server stop")
		server.Stop()
	case <-stopped:
		log.Info("Server stopped gracefully")
	}

	// Wait for all goroutines to finish
	wg.Wait()
	log.Info("Server shutdown complete")
}

// startMetricsServer starts a Prometheus metrics endpoint on a separate port
func startMetricsServer(ctx context.Context) {
	metricsAddr := ":" + metricsPort

	http.Handle("/metrics", promhttp.Handler())

	server := &http.Server{
		Addr:    metricsAddr,
		Handler: nil, // Use default mux
	}

	go func() {
		log.Infof("Starting metrics server on %s", metricsAddr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Errorf("Metrics server failed: %v", err)
		}
	}()

	// Ensure metrics server is shut down when main context is cancelled
	go func() {
		<-ctx.Done()

		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		log.Info("Shutting down metrics server...")
		if err := server.Shutdown(shutdownCtx); err != nil {
			log.Errorf("Failed to shut down metrics server: %v", err)
		}
	}()
}

// createGrpcServer creates a new gRPC server with appropriate configuration.
// Uses TLS if --tls flag is provided or GRPC_HELLO_SECURE is set to "Y".
func createGrpcServer() *grpc.Server {
	// Check command-line flag first, then environment variable for backward compatibility
	if *useTLS || os.Getenv("GRPC_HELLO_SECURE") == "Y" {
		return createSecureServer()
	}
	return createInsecureServer()
}

// createSecureServer creates a TLS-enabled gRPC server
func createSecureServer() *grpc.Server {
	cert, err := tls.LoadX509KeyPair(certChainPath, certKeyPath)
	if err != nil {
		log.Errorf("Failed to load TLS certificates: %v", err)
		log.Errorf("Certificate paths: key=%s, chain=%s", certKeyPath, certChainPath)
		log.Warn("Falling back to insecure server")
		return createInsecureServer()
	}

	tlsConfig := &tls.Config{
		ClientAuth:   tls.RequireAndVerifyClientCert,
		Certificates: []tls.Certificate{cert},
		ClientCAs:    conn.GetCertPool(rootCertPath),
		MinVersion:   tls.VersionTLS12, // Enforce minimum TLS 1.2 for security
	}

	// Combine TLS credentials with our other server options
	opts := getCommonServerOptions()
	opts = append(opts, grpc.Creds(credentials.NewTLS(tlsConfig)))

	server := grpc.NewServer(opts...)
	log.Info("TLS security enabled for gRPC server")

	return server
}

// createInsecureServer creates a gRPC server with keepalive and rate limiting options
func createInsecureServer() *grpc.Server {
	opts := getCommonServerOptions()
	server := grpc.NewServer(opts...)
	log.Info("Created insecure gRPC server")
	return server
}

// getCommonServerOptions returns common gRPC server options used by both secure and insecure servers
func getCommonServerOptions() []grpc.ServerOption {
	var opts []grpc.ServerOption

	// Add keepalive enforcement policy
	keepalivePolicy := keepalive.EnforcementPolicy{
		MinTime:             5 * time.Second, // Minimum time between client pings
		PermitWithoutStream: true,            // Allow pings even when there are no active streams
	}
	opts = append(opts, grpc.KeepaliveEnforcementPolicy(keepalivePolicy))

	// Add keepalive parameters
	keepaliveParams := keepalive.ServerParameters{
		MaxConnectionIdle:     15 * time.Second,                      // Close idle connections after 15 seconds
		MaxConnectionAge:      maxConnectionAgeSeconds * time.Second, // Close any connection older than 30 seconds
		MaxConnectionAgeGrace: 5 * time.Second,                       // Allow 5 seconds grace period for pending RPCs
		Time:                  5 * time.Second,                       // Ping interval to check connection liveness
		Timeout:               1 * time.Second,                       // Wait 1 second for ping ack before closing
	}
	opts = append(opts, grpc.KeepaliveParams(keepaliveParams))

	// Add logging interceptor
	loggingInterceptor := common.UnaryLoggingInterceptor()

	// Add rate limiting
	rateLimiter := common.NewLimiter(maxRequestsPerSecond)
	rateInterceptor := common.UnaryServerInterceptor(rateLimiter)

	// Combine interceptors
	chainedInterceptor := common.ChainUnaryInterceptors(loggingInterceptor, rateInterceptor)
	opts = append(opts, grpc.UnaryInterceptor(chainedInterceptor))

	return opts
}

// createServiceImplementation initializes the gRPC service implementation
func createServiceImplementation(ctx context.Context) service.ProtoServer {
	if conn.HasBackend() {
		return service.ProtoServer{
			BackendClient: *conn.Connect(),
		}
	}
	return service.ProtoServer{}
}

// registerWithServiceDiscovery registers the server with etcd if configured
func registerWithServiceDiscovery(ctx context.Context, address string) *register.EtcdRegister {
	if os.Getenv("GRPC_HELLO_DISCOVERY") != "etcd" {
		return nil
	}

	etcdRegister, err := register.NewEtcdRegister()
	if err != nil {
		log.Errorf("Failed to create etcd register: %v", err)
		return nil
	}

	// Register service with etcd
	serviceName := "hello-grpc"
	ttlSeconds := int64(5) // Changed from int to int64

	err = etcdRegister.RegisterServer("/etcd/"+serviceName, address, ttlSeconds)
	if err != nil {
		log.Errorf("Failed to register with etcd: %v", err)
		return nil
	}

	log.Infof("Registered with etcd service discovery as '%s'", serviceName)

	// Start background heartbeat to keep registration alive
	go func() {
		ticker := time.NewTicker(time.Duration(ttlSeconds-1) * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				log.Info("Stopping etcd heartbeat due to context cancellation")
				return
			case <-ticker.C:
				if err := etcdRegister.Heartbeat(); err != nil {
					log.Errorf("Failed to send etcd heartbeat: %v", err)
				}
			}
		}
	}()

	return etcdRegister
}
