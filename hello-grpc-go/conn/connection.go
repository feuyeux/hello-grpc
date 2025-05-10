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

func init() {
	switch runtime.GOOS {
	case "windows":
		certKey = "d:\\garden\\var\\hello_grpc\\client_certs\\private.key"
		certChain = "d:\\garden\\var\\hello_grpc\\client_certs\\full_chain.pem"
		rootCert = "d:\\garden\\var\\hello_grpc\\client_certs\\myssl_root.cer"
	case "linux", "darwin":
		certKey = "/var/hello_grpc/client_certs/private.key"
		certChain = "/var/hello_grpc/client_certs/full_chain.pem"
		rootCert = "/var/hello_grpc/client_certs/myssl_root.cer"
	default:
		log.Errorf("Unsupported OS: %s", runtime.GOOS)
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
			panic(err)
		}
		c := &tls.Config{
			ServerName:   serverName,
			Certificates: []tls.Certificate{cert},
			RootCAs:      GetCertPool(rootCert),
		}
		conn, err := grpc.NewClient("etcd:///",
			grpc.WithStatsHandler(&StatsHandler{}),
			grpc.WithTransportCredentials(credentials.NewTLS(c)),
			grpc.WithDefaultServiceConfig(grpcServiceConfig))
		if err != nil {
			panic(err)
		}
		return conn
	} else {
		log.Infof("Connect With InSecure through discovery")
		conn, err := grpc.NewClient("etcd:///",
			grpc.WithStatsHandler(&StatsHandler{}),
			grpc.WithTransportCredentials(insecure.NewCredentials()),
			grpc.WithDefaultServiceConfig(grpcServiceConfig))
		if err != nil {
			panic(err)
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
		c := &tls.Config{
			ServerName:   serverName,
			Certificates: []tls.Certificate{cert},
			RootCAs:      GetCertPool(rootCert),
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
	secure := os.Getenv("GRPC_HELLO_SECURE")
	if secure == "Y" {
		log.Infof("Connect With TLS(%s)", address)
		conn, _ = transportCredentials(address)
	} else {
		log.Infof("Connect With InSecure(%s)", address)
		conn, _ = transportInsecure(address)
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
	// see https://github.com/grpc/grpc/blob/master/doc/service_config.md to know more about service config
	retryPolicy := `{
		"methodConfig": [{
		  "name": [{"service": "GRPC_SERVER"}],
		  "waitForReady": true,
		  "retryPolicy": {
			  "MaxAttempts": 200,
			  "InitialBackoff": ".1s",
			  "MaxBackoff": ".05s",
			  "BackoffMultiplier": 1.2,
			  "RetryableStatusCodes": [ "UNAVAILABLE" ]
		  }
		}]}`
	// retry https://github.com/grpc/proposal/blob/master/A6-client-retries.md
	retryConfig := grpc.WithDefaultServiceConfig(retryPolicy)
	// rate limiting
	count := 10
	rateLimitConfig := grpc.WithUnaryInterceptor(common.UnaryClientInterceptor(common.NewLimiter(count)))
	// keepalive
	keepaliveConfig := grpc.WithKeepaliveParams(keepalive.ClientParameters{
		Time:                10 * time.Second, // send pings every 10 seconds if there is no activity
		Timeout:             time.Second,      // wait 1 second for ping ack before considering the connection dead
		PermitWithoutStream: true,             // send pings even without active streams
	})
	return grpc.NewClient(address,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		keepaliveConfig,
		retryConfig,
		rateLimitConfig,
	)
}

func transportInsecureWithContext(ctx context.Context, address string) (*grpc.ClientConn, error) {
	// see https://github.com/grpc/grpc/blob/master/doc/service_config.md to know more about service config
	retryPolicy := `{
		"methodConfig": [{
		  "name": [{"service": "GRPC_SERVER"}],
		  "waitForReady": true,
		  "retryPolicy": {
			  "MaxAttempts": 200,
			  "InitialBackoff": ".1s",
			  "MaxBackoff": ".05s",
			  "BackoffMultiplier": 1.2,
			  "RetryableStatusCodes": [ "UNAVAILABLE" ]
		  }
		}]}`
	// retry https://github.com/grpc/proposal/blob/master/A6-client-retries.md
	retryConfig := grpc.WithDefaultServiceConfig(retryPolicy)
	// rate limiting
	count := 10
	rateLimitConfig := grpc.WithUnaryInterceptor(common.UnaryClientInterceptor(common.NewLimiter(count)))
	// keepalive
	keepaliveConfig := grpc.WithKeepaliveParams(keepalive.ClientParameters{
		Time:                10 * time.Second, // send pings every 10 seconds if there is no activity
		Timeout:             time.Second,      // wait 1 second for ping ack before considering the connection dead
		PermitWithoutStream: true,             // send pings even without active streams
	})
	return grpc.DialContext(ctx, address,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		keepaliveConfig,
		retryConfig,
		rateLimitConfig,
	)
}

func transportCredentials(address string) (*grpc.ClientConn, error) {
	cert, err := tls.LoadX509KeyPair(certChain, certKey)
	if err != nil {
		panic(err)
	}
	return grpc.NewClient(address, grpc.WithTransportCredentials(credentials.NewTLS(&tls.Config{
		ServerName:   serverName,
		Certificates: []tls.Certificate{cert},
		RootCAs:      GetCertPool(rootCert),
	})))
}

func transportCredentialsWithContext(ctx context.Context, address string) (*grpc.ClientConn, error) {
	cert, err := tls.LoadX509KeyPair(certChain, certKey)
	if err != nil {
		return nil, fmt.Errorf("failed to load key pair: %w", err)
	}
	return grpc.DialContext(ctx, address, grpc.WithTransportCredentials(credentials.NewTLS(&tls.Config{
		ServerName:   serverName,
		Certificates: []tls.Certificate{cert},
		RootCAs:      GetCertPool(rootCert),
	})))
}

func GetCertPool(rootCert string) *x509.CertPool {
	certPool := x509.NewCertPool()
	bs, err := os.ReadFile(rootCert)
	if err != nil {
		panic(err)
	}
	if !certPool.AppendCertsFromPEM(bs) {
		panic("fail to append root cert")
	}
	return certPool
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
