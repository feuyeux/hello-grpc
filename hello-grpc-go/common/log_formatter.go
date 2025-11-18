package common

import (
	"context"
	"os"
	"time"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
)

const serviceName = "go"

var isSecureMode = os.Getenv("GRPC_HELLO_SECURE") == "Y"

// ExtractRequestID extracts request ID from context metadata
func ExtractRequestID(ctx context.Context) string {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return "unknown"
	}

	// Try multiple request ID header variants
	if v := md.Get("x-request-id"); len(v) > 0 {
		return v[0]
	}
	if v := md.Get("request-id"); len(v) > 0 {
		return v[0]
	}
	return "unknown"
}

// ExtractPeer extracts peer address from context
func ExtractPeer(ctx context.Context) string {
	if p, ok := peer.FromContext(ctx); ok {
		return p.Addr.String()
	}
	return "unknown"
}

// IsSecure checks if the connection is secure
func IsSecure(ctx context.Context) bool {
	if p, ok := peer.FromContext(ctx); ok && p.AuthInfo != nil {
		return true
	}
	return isSecureMode
}

// LogRequestStart logs the start of an RPC request
func LogRequestStart(ctx context.Context, method string) {
	requestID := ExtractRequestID(ctx)
	peerAddr := ExtractPeer(ctx)
	secure := IsSecure(ctx)

	log.WithFields(log.Fields{
		"service":    serviceName,
		"request_id": requestID,
		"method":     method,
		"peer":       peerAddr,
		"secure":     secure,
		"status":     "STARTED",
	}).Info("rpc_request")
}

// LogRequestEnd logs the completion of an RPC request
func LogRequestEnd(ctx context.Context, method string, startTime time.Time, err error) {
	requestID := ExtractRequestID(ctx)
	peerAddr := ExtractPeer(ctx)
	secure := IsSecure(ctx)
	durationMs := time.Since(startTime).Milliseconds()

	fields := log.Fields{
		"service":     serviceName,
		"request_id":  requestID,
		"method":      method,
		"peer":        peerAddr,
		"secure":      secure,
		"duration_ms": durationMs,
	}

	if err != nil {
		st, _ := status.FromError(err)
		fields["status"] = st.Code().String()
		fields["error_code"] = st.Code().String()
		fields["message"] = st.Message()
		log.WithFields(fields).Error("rpc_response")
	} else {
		fields["status"] = codes.OK.String()
		log.WithFields(fields).Info("rpc_response")
	}
}

// StreamLoggingInterceptor returns a gRPC interceptor that logs streaming RPC calls with unified format
func StreamLoggingInterceptor() grpc.StreamServerInterceptor {
	return func(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		startTime := time.Now()
		ctx := ss.Context()

		LogRequestStart(ctx, info.FullMethod)

		err := handler(srv, ss)

		LogRequestEnd(ctx, info.FullMethod, startTime, err)

		return err
	}
}
