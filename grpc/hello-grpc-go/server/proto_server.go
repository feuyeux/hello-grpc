package main

import (
	"crypto/tls"
	"google.golang.org/grpc/keepalive"
	"hello-grpc/common/pb"
	"hello-grpc/conn"
	"hello-grpc/server/service"
	"net"
	"os"
	"time"

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
		kep := keepalive.EnforcementPolicy{
			MinTime:             5 * time.Second, // If a client pings more than once every 5 seconds, terminate the connection
			PermitWithoutStream: true,            // Allow pings even when there are no active streams
		}

		kp := keepalive.ServerParameters{
			MaxConnectionIdle:     15 * time.Second, // If a client is idle for 15 seconds, send a GOAWAY
			MaxConnectionAge:      30 * time.Second, // If any connection is alive for more than 30 seconds, send a GOAWAY
			MaxConnectionAgeGrace: 5 * time.Second,  // Allow 5 seconds for pending RPCs to complete before forcibly closing connections
			Time:                  5 * time.Second,  // Ping the client if it is idle for 5 seconds to ensure the connection is still active
			Timeout:               1 * time.Second,  // Wait 1 second for the ping ack before assuming the connection is dead
		}

		s = grpc.NewServer(grpc.KeepaliveEnforcementPolicy(kep), grpc.KeepaliveParams(kp))
		log.Infof("Start GRPC Server[%s]", port)
	}

	if conn.HasBackend() {
		srv = service.ProtoServer{BackendClient: *conn.Connect()}
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
