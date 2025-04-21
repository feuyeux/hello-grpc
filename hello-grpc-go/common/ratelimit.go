package common

import (
	"context"

	grpcratelimit "github.com/grpc-ecosystem/go-grpc-middleware/ratelimit"
	log "github.com/sirupsen/logrus"
	"go.uber.org/ratelimit"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type limiter struct {
	ratelimit.Limiter
}

func (l *limiter) Limit() bool {
	log.Info("check limit")
	l.Take()
	return false
}

// NewLimiter return new go-grpc Limiter, specified the number of requests you want to limit as a counts per second.
func NewLimiter(count int) grpcratelimit.Limiter {
	return &limiter{
		Limiter: ratelimit.New(count),
	}
}

/*server side*/

// UnaryServerInterceptor return server unary interceptor that limit requests.
func UnaryServerInterceptor(limiter grpcratelimit.Limiter) grpc.UnaryServerInterceptor {
	return func(ctx context.Context,
		req interface{},
		info *grpc.UnaryServerInfo,
		handler grpc.UnaryHandler) (interface{}, error) {
		if limiter.Limit() {
			return nil, status.Errorf(codes.ResourceExhausted, "%s have been rejected by rate limiting.", info.FullMethod)
		} else {

			return handler(ctx, req)
		}
	}
}

// StreamServerInterceptor return server stream interceptor that limit requests.
func StreamServerInterceptor(limiter grpcratelimit.Limiter) grpc.StreamServerInterceptor {
	return func(srv interface{},
		stream grpc.ServerStream,
		info *grpc.StreamServerInfo,
		handler grpc.StreamHandler) error {
		if limiter.Limit() {
			return status.Errorf(codes.ResourceExhausted, "%s have been rejected by rate limiting.", info.FullMethod)
		} else {
			log.Infof("StreamServerInterceptor limiter:%+v", limiter)
			return handler(srv, stream)
		}
	}
}

/*client side*/

// UnaryClientInterceptor return client unary interceptor that limit requests.
func UnaryClientInterceptor(limiter grpcratelimit.Limiter) grpc.UnaryClientInterceptor {
	return func(ctx context.Context,
		method string,
		req, reply interface{},
		cc *grpc.ClientConn,
		invoker grpc.UnaryInvoker,
		opts ...grpc.CallOption) error {
		if limiter.Limit() {
			return status.Errorf(codes.ResourceExhausted, "%s have been rejected by rate limiting.", method)
		}
		return invoker(ctx, method, req, reply, cc, opts...)
	}
}

// StreamClientInterceptor return client stream interceptor that limit requests.
func StreamClientInterceptor(limiter grpcratelimit.Limiter) grpc.StreamClientInterceptor {
	return func(ctx context.Context,
		desc *grpc.StreamDesc,
		cc *grpc.ClientConn,
		method string,
		streamer grpc.Streamer,
		opts ...grpc.CallOption) (grpc.ClientStream, error) {
		if limiter.Limit() {
			return nil, status.Errorf(codes.ResourceExhausted, "%s have been rejected by rate limiting.", method)
		}
		return streamer(ctx, desc, cc, method, opts...)
	}
}
