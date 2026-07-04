package discover

import (
	"os"
	"testing"
)

func TestGetDiscoveryEndpointDefault(t *testing.T) {
	os.Unsetenv("GRPC_HELLO_DISCOVERY_ENDPOINT")
	ep := GetDiscoveryEndpoint()
	if ep != "127.0.0.1:2379" {
		t.Errorf("expected '127.0.0.1:2379', got '%s'", ep)
	}
}

func TestGetDiscoveryEndpointFromEnv(t *testing.T) {
	os.Setenv("GRPC_HELLO_DISCOVERY_ENDPOINT", "etcd.example.com:2379")
	defer os.Unsetenv("GRPC_HELLO_DISCOVERY_ENDPOINT")
	ep := GetDiscoveryEndpoint()
	if ep != "etcd.example.com:2379" {
		t.Errorf("expected 'etcd.example.com:2379', got '%s'", ep)
	}
}
