/*
 * grpc demo
 */

package main

import (
	"crypto/tls"
	"net"
	"os"

	"github.com/feuyeux/hello-grpc-go/common/pb"
	"github.com/feuyeux/hello-grpc-go/conn"
	"github.com/feuyeux/hello-grpc-go/server"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/reflection"
)

var (
	cert      = "/var/hello_grpc/server_certs/cert.pem"
	certKey   = "/var/hello_grpc/server_certs/private.key"
	certChain = "/var/hello_grpc/server_certs/full_chain.pem"
	rootCert  = "/var/hello_grpc/server_certs/myssl_root.cer"
)

func main() {
	lis, err := net.Listen("tcp", conn.Port())
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
		return
	}
	var s *grpc.Server
	var srv *server.ProtoServer
	if os.Getenv("GRPC_HELLO_SECURE") == "Y" {
		cert, err := tls.LoadX509KeyPair(certChain, certKey)
		if err != nil {
			panic(err)
		}
		s = grpc.NewServer(grpc.Creds(credentials.NewTLS(&tls.Config{
			ClientAuth:   tls.RequireAndVerifyClientCert,
			Certificates: []tls.Certificate{cert},
			ClientCAs:    conn.GetCertPool(rootCert),
		})))
		log.Info("Start GRPC TLS Server")
	} else {
		s = grpc.NewServer()
		log.Info("Start GRPC Server")
	}

	if conn.HasBackend() {
		conn, err := conn.Dial()
		if err != nil {
			log.Fatalf("Did not connect: %v", err)
		}
		defer conn.Close()
		c := pb.NewLandingServiceClient(conn)
		srv = &server.ProtoServer{BackendClient: c}
	} else {
		srv = &server.ProtoServer{}
	}
	pb.RegisterLandingServiceServer(s, srv)
	// Register reflection service on gRPC server.
	reflection.Register(s)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
