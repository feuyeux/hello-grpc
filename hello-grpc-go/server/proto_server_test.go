package main

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

type authTestStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (s *authTestStream) Context() context.Context { return s.ctx }

func TestAuthStreamInterceptor(t *testing.T) {
	interceptor := authStreamInterceptor("secret")
	info := &grpc.StreamServerInfo{FullMethod: "/hello.LandingService/TalkBidirectional"}

	called := false
	handler := func(_ interface{}, _ grpc.ServerStream) error {
		called = true
		return nil
	}

	err := interceptor(nil, &authTestStream{ctx: context.Background()}, info, handler)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
	assert.False(t, called)

	ctx := metadata.NewIncomingContext(context.Background(), metadata.Pairs("authorization", "Bearer secret"))
	err = interceptor(nil, &authTestStream{ctx: ctx}, info, handler)
	assert.NoError(t, err)
	assert.True(t, called)
}
