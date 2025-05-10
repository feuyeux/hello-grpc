package common

import (
	"context"
	"time"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
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
