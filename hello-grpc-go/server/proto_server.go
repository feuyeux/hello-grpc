package main

import (
	"crypto/tls"
	"hello-grpc/common"
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
		var opts []grpc.ServerOption
		// keepalive policy opts
		kep := keepalive.EnforcementPolicy{
			// If a client pings more than once every 5 seconds, terminate the connection
			MinTime: 5 * time.Second,
			// Allow pings even when there are no active streams
			PermitWithoutStream: true,
		}
		opts = append(opts, grpc.KeepaliveEnforcementPolicy(kep))
		// keepalive opts
		kp := keepalive.ServerParameters{
			// If a client is idle for 15 seconds, send a GOAWAY
			MaxConnectionIdle: 15 * time.Second,
			// If any connection is alive for more than 30 seconds, send a GOAWAY
			MaxConnectionAge: 30 * time.Second,
			// Allow 5 seconds for pending RPCs to complete before forcibly closing connections
			MaxConnectionAgeGrace: 5 * time.Second,
			// Ping the client if it is idle for 5 seconds to ensure the connection is still active
			Time: 5 * time.Second,
			// Wait 1 second for the ping ack before assuming the connection is dead
			Timeout: 1 * time.Second,
		}
		opts = append(opts, grpc.KeepaliveParams(kp))
		// limits opts
		limits := 200
		rlInterceptor := common.UnaryServerInterceptor(common.NewLimiter(limits))
		opts = append(opts, grpc.UnaryInterceptor(rlInterceptor))
		// builder
		s = grpc.NewServer(opts...)
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
		defer func(etcdRegister *register.EtcdRegister) {
			_ = etcdRegister.Close()
		}(etcdRegister)
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
