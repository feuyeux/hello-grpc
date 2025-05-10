package common

import (
	"fmt"
	"google.golang.org/grpc"
	"strconv"
	"strings"
	"testing"
)

func TestGetAnswerMap(t *testing.T) {
	hello := GetHelloList()[1]
	ans := GetAnswerMap()[hello]
	if ans != "Merci beaucoup" {
		t.Errorf("Expected 'Merci beaucoup', got '%s'", ans)
	}
	println(ans)
}

func TestRand(t *testing.T) {
	id := RandomId(5)
	index, _ := strconv.Atoi(id)
	fmt.Printf("%s,%d", id, index)
}

func TestGetVersion(t *testing.T) {
	// Get the version string
	version := GetVersion()

	// 直接打印输出 GetVersion 的值
	fmt.Println("GetVersion value:", version)

	// Test that the version string starts with the expected prefix
	if !strings.HasPrefix(version, "grpc.version=") {
		t.Error("Version string does not start with 'grpc.version='")
	}

	// Test that the version is not empty (beyond the prefix)
	if len(version) <= 13 { // "grpc.version=" is 13 characters
		t.Error("Version string is too short")
	}

	// Test that it returns the same value as grpc.Version
	expectedVersion := "grpc.version=" + grpc.Version
	if version != expectedVersion {
		t.Errorf("Expected version '%s', got '%s'", expectedVersion, version)
	}
}
