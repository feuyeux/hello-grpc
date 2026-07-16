package common

import (
	"context"
	"fmt"
	"time"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// UnaryLoggingInterceptor returns a gRPC interceptor that logs unary RPC calls
func UnaryLoggingInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		start := time.Now()
		log.Infof("Request: %s", info.FullMethod)

		resp, err := handler(ctx, req)

		log.Infof("Response: %s (took %v)", info.FullMethod, time.Since(start))
		if err != nil {
			log.Errorf("Error in %s: %v", info.FullMethod, err)
		}

		return resp, err
	}
}

// ChainUnaryInterceptors creates a single interceptor from multiple interceptors
func ChainUnaryInterceptors(interceptors ...grpc.UnaryServerInterceptor) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		buildChain := func(current grpc.UnaryServerInterceptor, next grpc.UnaryHandler) grpc.UnaryHandler {
			return func(currentCtx context.Context, currentReq interface{}) (interface{}, error) {
				return current(currentCtx, currentReq, info, next)
			}
		}

		chain := handler
		for i := len(interceptors) - 1; i >= 0; i-- {
			chain = buildChain(interceptors[i], chain)
		}

		return chain(ctx, req)
	}
}

// ChainStreamInterceptors creates a single stream interceptor from multiple interceptors.
func ChainStreamInterceptors(interceptors ...grpc.StreamServerInterceptor) grpc.StreamServerInterceptor {
	return func(srv interface{}, stream grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		chain := handler
		for i := len(interceptors) - 1; i >= 0; i-- {
			current := interceptors[i]
			next := chain
			chain = func(currentSrv interface{}, currentStream grpc.ServerStream) error {
				return current(currentSrv, currentStream, info, next)
			}
		}
		return chain(srv, stream)
	}
}

// UnaryRecoveryInterceptor converts handler panics into INTERNAL status errors
// so malformed requests cannot terminate the server process.
func UnaryRecoveryInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp interface{}, err error) {
		defer func() {
			if recovered := recover(); recovered != nil {
				log.Errorf("Recovered panic in %s: %v", info.FullMethod, recovered)
				err = status.Error(codes.Internal, fmt.Sprintf("internal server error in %s", info.FullMethod))
			}
		}()
		return handler(ctx, req)
	}
}

// StreamRecoveryInterceptor is the streaming equivalent of UnaryRecoveryInterceptor.
func StreamRecoveryInterceptor() grpc.StreamServerInterceptor {
	return func(srv interface{}, stream grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) (err error) {
		defer func() {
			if recovered := recover(); recovered != nil {
				log.Errorf("Recovered panic in %s: %v", info.FullMethod, recovered)
				err = status.Error(codes.Internal, fmt.Sprintf("internal server error in %s", info.FullMethod))
			}
		}()
		return handler(srv, stream)
	}
}
