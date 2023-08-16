package main

import (
	"crypto/tls"
	"hello-grpc/common/pb"
	"hello-grpc/conn"
	"hello-grpc/etcd/register"
	"hello-grpc/server/service"
	"net"
	"os"
	"time"

	"google.golang.org/grpc/keepalive"

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
	host := conn.GrpcServerHost()
	port := conn.GrpcServerPort()
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
	address := host + ":" + port
	log.Infof("address %s", address)
	lis, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
		return
	}

	// 注册服务
	if os.Getenv("GRPC_HELLO_DISCOVERY") == "etcd" {
		etcdRegister, err := register.NewEtcdRegister()
		if err != nil {
			log.Errorln(err)
			return
		}
		defer etcdRegister.Close()
		svcDiscName := "hello-grpc"
		err = etcdRegister.RegisterServer("/etcd/"+svcDiscName, address, 5)
		if err != nil {
			log.Errorf("register error %v \n", err)
			return
		}
	}

	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
