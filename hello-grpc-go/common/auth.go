package common

import (
	"context"
	"crypto/subtle"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// GRPC_HELLO_AUTH_TOKEN, when set on both client and server, enables a
// per-call bearer token credential demo: the client attaches an
// "authorization: Bearer <token>" header to every RPC, and the server
// validates it in a unary/stream interceptor before invoking the handler.
//
// This is a minimal illustration of gRPC CallCredentials / per-RPC auth
// (https://grpc.io/docs/guides/auth/), not a production authentication
// scheme: the token is a static shared secret compared in constant time,
// with no rotation, expiry, or identity claims. Real deployments should
// use short-lived tokens (e.g. OAuth2/JWT) verified against an identity
// provider. When GRPC_HELLO_AUTH_TOKEN is unset, this feature is a no-op
// and default (no-auth) behavior is unchanged.
const AuthTokenEnvVar = "GRPC_HELLO_AUTH_TOKEN"
const authMetadataKey = "authorization"
const authScheme = "Bearer "

// tokenCredentials implements credentials.PerRPCCredentials, attaching a
// static bearer token to every outgoing RPC.
type tokenCredentials struct {
	token          string
	requireTLS bool
}

// NewTokenCredentials returns per-RPC credentials that attach the given
// bearer token as an "authorization" header. requireTLS should mirror
// whether the underlying channel is secure: bearer tokens must not be
// sent in the clear, so callers should only pass requireTLS=false for
// local/demo insecure channels, matching this repo's GRPC_HELLO_SECURE
// convention.
func NewTokenCredentials(token string, requireTLS bool) credentialsPerRPC {
	return tokenCredentials{token: token, requireTLS: requireTLS}
}

// GetRequestMetadata implements credentials.PerRPCCredentials.
func (t tokenCredentials) GetRequestMetadata(ctx context.Context, uri ...string) (map[string]string, error) {
	return map[string]string{authMetadataKey: authScheme + t.token}, nil
}

// RequireTransportSecurity implements credentials.PerRPCCredentials.
func (t tokenCredentials) RequireTransportSecurity() bool {
	return t.requireTLS
}

// credentialsPerRPC is a local alias so this file does not have to import
// google.golang.org/grpc/credentials just for the interface type; callers
// pass the returned value straight into grpc.WithPerRPCCredentials, which
// accepts anything satisfying credentials.PerRPCCredentials structurally.
type credentialsPerRPC interface {
	GetRequestMetadata(ctx context.Context, uri ...string) (map[string]string, error)
	RequireTransportSecurity() bool
}

// ValidateAuthToken checks the incoming context's "authorization" metadata
// against the expected bearer token using a constant-time comparison, and
// returns a codes.Unauthenticated status error when it does not match (or
// is missing).
func ValidateAuthToken(ctx context.Context, expectedToken string) error {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return status.Error(codes.Unauthenticated, "missing authorization metadata")
	}
	values := md.Get(authMetadataKey)
	if len(values) == 0 {
		return status.Error(codes.Unauthenticated, "missing authorization header")
	}
	presented := values[0]
	expected := authScheme + expectedToken
	if subtle.ConstantTimeCompare([]byte(presented), []byte(expected)) != 1 {
		return status.Error(codes.Unauthenticated, "invalid bearer token")
	}
	return nil
}
