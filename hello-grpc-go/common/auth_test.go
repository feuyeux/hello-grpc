package common

import (
	"context"
	"testing"

	"google.golang.org/grpc/metadata"
)

func TestNewTokenCredentialsMetadata(t *testing.T) {
	creds := NewTokenCredentials("secret-token", true)
	md, err := creds.GetRequestMetadata(context.Background())
	if err != nil {
		t.Fatalf("GetRequestMetadata returned error: %v", err)
	}
	if md["authorization"] != "Bearer secret-token" {
		t.Errorf("expected 'Bearer secret-token', got '%s'", md["authorization"])
	}
}

func TestNewTokenCredentialsRequireTLS(t *testing.T) {
	creds := NewTokenCredentials("secret-token", true)
	if !creds.RequireTransportSecurity() {
		t.Error("expected RequireTransportSecurity to be true")
	}
}

func TestNewTokenCredentialsInsecure(t *testing.T) {
	creds := NewTokenCredentials("secret-token", false)
	if creds.RequireTransportSecurity() {
		t.Error("expected RequireTransportSecurity to be false")
	}
}

func TestValidateAuthTokenValid(t *testing.T) {
	ctx := metadata.NewIncomingContext(
		context.Background(),
		metadata.Pairs("authorization", "Bearer my-token"),
	)
	if err := ValidateAuthToken(ctx, "my-token"); err != nil {
		t.Errorf("expected nil error for valid token, got: %v", err)
	}
}

func TestValidateAuthTokenInvalid(t *testing.T) {
	ctx := metadata.NewIncomingContext(
		context.Background(),
		metadata.Pairs("authorization", "Bearer wrong-token"),
	)
	if err := ValidateAuthToken(ctx, "my-token"); err == nil {
		t.Error("expected error for wrong token, got nil")
	}
}

func TestValidateAuthTokenMissing(t *testing.T) {
	ctx := metadata.NewIncomingContext(
		context.Background(),
		metadata.Pairs("other", "value"),
	)
	if err := ValidateAuthToken(ctx, "my-token"); err == nil {
		t.Error("expected error for missing authorization header, got nil")
	}
}

func TestValidateAuthTokenNoMetadata(t *testing.T) {
	ctx := context.Background()
	if err := ValidateAuthToken(ctx, "my-token"); err == nil {
		t.Error("expected error for context without metadata, got nil")
	}
}
