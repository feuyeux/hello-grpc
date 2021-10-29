package conn

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io/ioutil"
	"os"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
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
		port = GrpcServerPort()
		address = fmt.Sprintf("%s:%s", grpcServerHost(), port)
	}

	secure := os.Getenv("GRPC_HELLO_SECURE")
	if secure == "Y" {
		log.Infof("Connect With TLS(%s)", port)
		return transportCredentials(address)
	}
	log.Infof("Connect With InSecure(%s)", port)
	return insecure(address)
}

func insecure(address string) (*grpc.ClientConn, error) {
	return grpc.Dial(address, grpc.WithInsecure())
}

func transportCredentials(address string) (*grpc.ClientConn, error) {
	cert, err := tls.LoadX509KeyPair(certChain, certKey)
	if err != nil {
		panic(err)
	}
	return grpc.Dial(address, grpc.WithTransportCredentials(credentials.NewTLS(&tls.Config{
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

func HasBackend() bool {
	return len(getBackend()) > 0
}

func getBackend() string {
	return os.Getenv("GRPC_HELLO_BACKEND")
}

func grpcServerHost() string {
	server := os.Getenv("GRPC_SERVER")
	if len(server) == 0 {
		return "localhost"
	} else {
		return server
	}
}
func GrpcServerPort() string {
	port := 9996
	currentPort := os.Getenv("GRPC_SERVER_PORT")
	if len(currentPort) == 0 {
		return fmt.Sprintf("%d", port)
	} else {
		return currentPort
	}
}
