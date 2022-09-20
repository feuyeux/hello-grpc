package main

import (
	"crypto/tls"
	"hello-grpc/common/pb"
	"hello-grpc/conn"
	"hello-grpc/server/service"
	"net"
	"os"

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
	port := conn.GrpcServerPort()
	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
		return
	}
	var s *grpc.Server
	var srv service.ProtoServer
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
		log.Infof("Start GRPC TLS Server[%s]", port)
	} else {
		s = grpc.NewServer()
		log.Infof("Start GRPC Server[%s]", port)
	}

	if conn.HasBackend() {
		con, err := conn.Dial()
		if err != nil {
			log.Fatalf("Did not connect: %v", err)
		}
		defer con.Close()
		c := pb.NewLandingServiceClient(con)
		srv = service.ProtoServer{BackendClient: c}
	} else {
		srv = service.ProtoServer{}
	}
	pb.RegisterLandingServiceServer(s, &srv)
	// Register reflection service on gRPC server.
	reflection.Register(s)

	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
