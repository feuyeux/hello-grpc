package conn

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"hello-grpc/common"
	"hello-grpc/common/pb"
	"hello-grpc/etcd/discover"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/keepalive"
	"google.golang.org/grpc/resolver"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

var (
	//https://myssl.com/create_test_cert.html
	certKey   string
	certChain string
	rootCert  string
	//cert       = "/var/hello_grpc/client_certs/cert.pem"
	serverName = "hello.grpc.io"
)

// defaultRetryServiceConfig enables transparent client retries for
// hello.LandingService following gRPC A6 client retries:
// https://github.com/grpc/proposal/blob/master/A6-client-retries.md
// See https://github.com/grpc/grpc/blob/master/doc/service_config.md for the format.
const defaultRetryServiceConfig = `{
	"methodConfig": [{
	  "name": [{"service": "hello.LandingService"}],
	  "waitForReady": true,
	  "retryPolicy": {
		  "MaxAttempts": 4,
		  "InitialBackoff": ".1s",
		  "MaxBackoff": "1s",
		  "BackoffMultiplier": 2.0,
		  "RetryableStatusCodes": [ "UNAVAILABLE" ]
	  }
	}]}`

// defaultKeepaliveParams keeps idle HTTP/2 connections alive on every
// client transport (secure and insecure).
var defaultKeepaliveParams = keepalive.ClientParameters{
	Time:                10 * time.Second, // send pings every 10 seconds if there is no activity
	Timeout:             time.Second,      // wait 1 second for ping ack before considering the connection dead
	PermitWithoutStream: true,             // send pings even without active streams
}

func init() {
	// CERT_BASE_PATH points at the directory that contains the client
	// certificates. It takes precedence over the platform defaults.
	if base := os.Getenv("CERT_BASE_PATH"); base != "" {
		certKey = filepath.Join(base, "private.key")
		certChain = filepath.Join(base, "full_chain.pem")
		rootCert = filepath.Join(base, "myssl_root.cer")
		return
	}
	switch runtime.GOOS {
	case "windows":
		certKey = "d:\\garden\\var\\hello_grpc\\client_certs\\private.key"
		certChain = "d:\\garden\\var\\hello_grpc\\client_certs\\full_chain.pem"
		rootCert = "d:\\garden\\var\\hello_grpc\\client_certs\\myssl_root.cer"
	case "darwin": // macOS
		certKey = "/var/hello_grpc/client_certs/private.key"
		certChain = "/var/hello_grpc/client_certs/full_chain.pem"
		rootCert = "/var/hello_grpc/client_certs/myssl_root.cer"
	case "linux":
		certKey = "/var/hello_grpc/client_certs/private.key"
		certChain = "/var/hello_grpc/client_certs/full_chain.pem"
		rootCert = "/var/hello_grpc/client_certs/myssl_root.cer"
	default:
		log.Errorf("Unsupported OS: %s", runtime.GOOS)
		certKey = "/var/hello_grpc/client_certs/private.key"
		certChain = "/var/hello_grpc/client_certs/full_chain.pem"
		rootCert = "/var/hello_grpc/client_certs/myssl_root.cer"
	}
}

func Connect() *pb.LandingServiceClient {
	var address string
	var port string
	if HasBackend() {
		backend := getBackend()
		backPort := os.Getenv("GRPC_HELLO_BACKEND_PORT")
		if len(backPort) > 0 {
			port = backPort
		} else {
			port = GrpcServerPort()
		}
		address = fmt.Sprintf("%s:%s", backend, port)
	} else {
		host := GrpcServerHost()
		port = GrpcServerPort()
		if len(host) == 0 {
			host = "localhost"
		}
		address = fmt.Sprintf("%s:%s", host, port)
	}
	discovery := os.Getenv("GRPC_HELLO_DISCOVERY")
	var client pb.LandingServiceClient
	if discovery == "etcd" {
		client = pb.NewLandingServiceClient(buildConnByDisc())
	} else {
		client = pb.NewLandingServiceClient(buildConn(address))
	}
	return &client
}

// ConnectWithContext establishes a connection to the gRPC server using the provided context
func ConnectWithContext(ctx context.Context) (*grpc.ClientConn, error) {
	var address string
	var port string
	if HasBackend() {
		backend := getBackend()
		backPort := os.Getenv("GRPC_HELLO_BACKEND_PORT")
		if len(backPort) > 0 {
			port = backPort
		} else {
			port = GrpcServerPort()
		}
		address = fmt.Sprintf("%s:%s", backend, port)
	} else {
		host := GrpcServerHost()
		port = GrpcServerPort()
		if len(host) == 0 {
			host = "localhost"
		}
		address = fmt.Sprintf("%s:%s", host, port)
	}
	discovery := os.Getenv("GRPC_HELLO_DISCOVERY")
	if discovery == "etcd" {
		return buildConnByDiscWithContext(ctx)
	} else {
		return buildConnWithContext(ctx, address)
	}
}

func buildConnByDisc() *grpc.ClientConn {
	etcdResolverBuilder := discover.NewEtcdResolverBuilder()
	resolver.Register(etcdResolverBuilder)
	const grpcServiceConfig = `{"loadBalancingPolicy":"round_robin"}`
	secure := os.Getenv("GRPC_HELLO_SECURE")
	if secure == "Y" {
		log.Infof("Connect With TLS through discovery")
		cert, err := tls.LoadX509KeyPair(certChain, certKey)
		if err != nil {
			log.Fatalf("failed to load client key pair (%s, %s): %v", certChain, certKey, err)
		}
		pool, err := GetCertPool(rootCert)
		if err != nil {
			log.Fatalf("failed to load root cert %s: %v", rootCert, err)
		}
		c := &tls.Config{
			ServerName:   serverName,
			Certificates: []tls.Certificate{cert},
			RootCAs:      pool,
		}
		conn, err := grpc.NewClient("etcd:///",
			grpc.WithStatsHandler(&StatsHandler{}),
			grpc.WithTransportCredentials(credentials.NewTLS(c)),
			grpc.WithDefaultServiceConfig(grpcServiceConfig))
		if err != nil {
			log.Fatalf("failed to create gRPC client: %v", err)
		}
		return conn
	} else {
		log.Infof("Connect With InSecure through discovery")
		conn, err := grpc.NewClient("etcd:///",
			grpc.WithStatsHandler(&StatsHandler{}),
			grpc.WithTransportCredentials(insecure.NewCredentials()),
			grpc.WithDefaultServiceConfig(grpcServiceConfig))
		if err != nil {
			log.Fatalf("failed to create gRPC client: %v", err)
		}
		return conn
	}
}

func buildConnByDiscWithContext(ctx context.Context) (*grpc.ClientConn, error) {
	etcdResolverBuilder := discover.NewEtcdResolverBuilder()
	resolver.Register(etcdResolverBuilder)
	const grpcServiceConfig = `{"loadBalancingPolicy":"round_robin"}`
	secure := os.Getenv("GRPC_HELLO_SECURE")
	if secure == "Y" {
		log.Infof("Connect With TLS through discovery")
		cert, err := tls.LoadX509KeyPair(certChain, certKey)
		if err != nil {
			return nil, fmt.Errorf("failed to load key pair: %w", err)
		}
		pool, err := GetCertPool(rootCert)
		if err != nil {
			return nil, fmt.Errorf("failed to load root cert: %w", err)
		}
		c := &tls.Config{
			ServerName:   serverName,
			Certificates: []tls.Certificate{cert},
			RootCAs:      pool,
		}
		return grpc.DialContext(ctx, "etcd:///",
			grpc.WithStatsHandler(&StatsHandler{}),
			grpc.WithTransportCredentials(credentials.NewTLS(c)),
			grpc.WithDefaultServiceConfig(grpcServiceConfig))
	} else {
		log.Infof("Connect With InSecure through discovery")
		return grpc.DialContext(ctx, "etcd:///",
			grpc.WithStatsHandler(&StatsHandler{}),
			grpc.WithTransportCredentials(insecure.NewCredentials()),
			grpc.WithDefaultServiceConfig(grpcServiceConfig))
	}
}

func buildConn(address string) *grpc.ClientConn {
	var conn *grpc.ClientConn
	var err error
	secure := os.Getenv("GRPC_HELLO_SECURE")
	if secure == "Y" {
		log.Infof("Connect With TLS(%s)", address)
		conn, err = transportCredentials(address)
	} else {
		log.Infof("Connect With InSecure(%s)", address)
		conn, err = transportInsecure(address)
	}
	if err != nil {
		log.Fatalf("failed to build connection to %s: %v", address, err)
	}
	return conn
}

func buildConnWithContext(ctx context.Context, address string) (*grpc.ClientConn, error) {
	secure := os.Getenv("GRPC_HELLO_SECURE")
	if secure == "Y" {
		log.Infof("Connect With TLS(%s)", address)
		return transportCredentialsWithContext(ctx, address)
	} else {
		log.Infof("Connect With InSecure(%s)", address)
		return transportInsecureWithContext(ctx, address)
	}
}

func transportInsecure(address string) (*grpc.ClientConn, error) {
	retryConfig := grpc.WithDefaultServiceConfig(defaultRetryServiceConfig)
	// rate limiting (+ OpenTelemetry unary client interceptor when
	// GRPC_HELLO_OTEL=Y). grpc.WithUnaryInterceptor only accepts a
	// single interceptor, so the chain helper composes rate-limit and
	// otelgrpc.ClientUnary together; both are nil-safe (chain returns
	// nil when both halves are nil so the option is omitted).
	count := 10
	rateLimitConfig := grpc.WithChainUnaryInterceptor(clientInterceptorChain(count)...)
	keepaliveConfig := grpc.WithKeepaliveParams(defaultKeepaliveParams)
	dialOpts := []grpc.DialOption{
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		keepaliveConfig,
		retryConfig,
		rateLimitConfig,
	}
	// OpenTelemetry stats handler: traces both unary and stream RPCs in
	// a single grpc.StatsHandler. The handler is a no-op when GRPC_HELLO_OTEL
	// is not "Y".
	if _, otelClient := common.OtelInterceptors(); otelClient != nil {
		dialOpts = append(dialOpts, grpc.WithStatsHandler(otelClient))
	}
	return grpc.NewClient(address, dialOpts...)
}

func transportInsecureWithContext(ctx context.Context, address string) (*grpc.ClientConn, error) {
	retryConfig := grpc.WithDefaultServiceConfig(defaultRetryServiceConfig)
	// rate limiting (+ OpenTelemetry unary client interceptor when
	// GRPC_HELLO_OTEL=Y, threaded through clientInterceptorChain).
	count := 10
	rateLimitConfig := grpc.WithChainUnaryInterceptor(clientInterceptorChain(count)...)
	keepaliveConfig := grpc.WithKeepaliveParams(defaultKeepaliveParams)
	dialOpts := []grpc.DialOption{
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		keepaliveConfig,
		retryConfig,
		rateLimitConfig,
	}
	// OpenTelemetry stats handler: traces both unary and stream RPCs in
	// a single grpc.StatsHandler. The handler is a no-op when GRPC_HELLO_OTEL
	// is not "Y".
	if _, otelClient := common.OtelInterceptors(); otelClient != nil {
		dialOpts = append(dialOpts, grpc.WithStatsHandler(otelClient))
	}
	return grpc.DialContext(ctx, address, dialOpts...)
}

// clientInterceptorChain builds the chained unary client interceptor slice
// passed to grpc.WithChainUnaryInterceptor. It includes the always-on
// rate-limit interceptor plus the OpenTelemetry unary client interceptor
// when GRPC_HELLO_OTEL=Y. Returns nil when neither is desired so the
// caller skips the option entirely (keeps the default behavior).
func clientInterceptorChain(rateBudget int) []grpc.UnaryClientInterceptor {
	chain := []grpc.UnaryClientInterceptor{common.UnaryClientInterceptor(common.NewLimiter(rateBudget))}
	// OTel is wired via grpc.WithStatsHandler at the call site, not as a
	// unary interceptor in this chain — see transportInsecure etc.
	return chain
}

func transportCredentials(address string) (*grpc.ClientConn, error) {
	cert, err := tls.LoadX509KeyPair(certChain, certKey)
	if err != nil {
		return nil, fmt.Errorf("failed to load key pair: %w", err)
	}
	pool, err := GetCertPool(rootCert)
	if err != nil {
		return nil, fmt.Errorf("failed to load root cert: %w", err)
	}
	return grpc.NewClient(address,
		grpc.WithTransportCredentials(credentials.NewTLS(&tls.Config{
			ServerName:   serverName,
			Certificates: []tls.Certificate{cert},
			RootCAs:      pool,
		})),
		grpc.WithKeepaliveParams(defaultKeepaliveParams),
		grpc.WithDefaultServiceConfig(defaultRetryServiceConfig))
}

func transportCredentialsWithContext(ctx context.Context, address string) (*grpc.ClientConn, error) {
	cert, err := tls.LoadX509KeyPair(certChain, certKey)
	if err != nil {
		return nil, fmt.Errorf("failed to load key pair: %w", err)
	}
	pool, err := GetCertPool(rootCert)
	if err != nil {
		return nil, fmt.Errorf("failed to load root cert: %w", err)
	}
	return grpc.DialContext(ctx, address,
		grpc.WithTransportCredentials(credentials.NewTLS(&tls.Config{
			ServerName:   serverName,
			Certificates: []tls.Certificate{cert},
			RootCAs:      pool,
		})),
		grpc.WithKeepaliveParams(defaultKeepaliveParams),
		grpc.WithDefaultServiceConfig(defaultRetryServiceConfig))
}

func GetCertPool(rootCert string) (*x509.CertPool, error) {
	certPool := x509.NewCertPool()
	bs, err := os.ReadFile(rootCert)
	if err != nil {
		return nil, fmt.Errorf("failed to read root cert %s: %w", rootCert, err)
	}
	if !certPool.AppendCertsFromPEM(bs) {
		return nil, fmt.Errorf("failed to append root cert %s", rootCert)
	}
	return certPool, nil
}

func HasBackend() bool {
	return len(getBackend()) > 0
}

func getBackend() string {
	return os.Getenv("GRPC_HELLO_BACKEND")
}

func GrpcServerHost() string {
	return os.Getenv("GRPC_SERVER")
}

var port = 9996

func GrpcServerPort() string {
	currentPort := os.Getenv("GRPC_SERVER_PORT")
	if len(currentPort) == 0 {
		return fmt.Sprintf("%d", port)
	} else {
		return currentPort
	}
}
