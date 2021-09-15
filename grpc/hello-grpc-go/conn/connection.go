package conn

import (
	"crypto/tls"
	"crypto/x509"
	"io/ioutil"
	"os"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

const (
	port = ":9996"
)

var (
	//https://myssl.com/create_test_cert.html
	cert       = "/var/hello_grpc/client_certs/cert.pem"
	certKey    = "/var/hello_grpc/client_certs/private.key"
	certChain  = "/var/hello_grpc/client_certs/full_chain.pem"
	rootCert   = "/var/hello_grpc/client_certs/myssl_root.cer"
	serverName = "hello.grpc.io"
)

func Dial() (*grpc.ClientConn, error) {
	secure := os.Getenv("GRPC_HELLO_SECURE")
	if secure == "Y" {
		log.Info("Connect With TLS")
		return transportCredentials()
	}
	log.Info("Connect With InSecure")
	return insecure()
}

func insecure() (*grpc.ClientConn, error) {
	return grpc.Dial(grpcServerAddress(), grpc.WithInsecure())
}

func transportCredentials() (*grpc.ClientConn, error) {
	cert, err := tls.LoadX509KeyPair(certChain, certKey)
	if err != nil {
		panic(err)
	}
	return grpc.Dial(grpcServerAddress(), grpc.WithTransportCredentials(credentials.NewTLS(&tls.Config{
		ServerName:   serverName,
		Certificates: []tls.Certificate{cert},
		RootCAs:      GetCertPool(rootCert),
	})))
}

func GetCertPool(rootCert string) *x509.CertPool {
	certPool := x509.NewCertPool()
	bs, err := ioutil.ReadFile(rootCert)
	if err != nil {
		panic(err)
	}
	if !certPool.AppendCertsFromPEM(bs) {
		panic("fail to append root cert")
	}
	return certPool
}

func grpcServerAddress() string {
	if HasBackend() {
		backend := getBackend()
		backPort := os.Getenv("GRPC_HELLO_BACKEND_PORT")
		log.Infof("Start GRPC Server backend:%v", backend)
		if len(backPort) > 0 {
			return backend + ":" + backPort
		} else {
			return backend + port
		}
	} else {
		return grpcServer() + port
	}
}

func HasBackend() bool {
	return len(getBackend()) > 0
}

func getBackend() string {
	return os.Getenv("GRPC_HELLO_BACKEND")
}

func grpcServer() string {
	server := os.Getenv("GRPC_SERVER")
	if len(server) == 0 {
		return "localhost"
	} else {
		return server
	}
}

func Port() string {
	currentPort := os.Getenv("GRPC_HELLO_PORT")
	if len(currentPort) == 0 {
		return port

	} else {
		return ":" + currentPort
	}
}
