// Package common provides shared utilities and helper functions for the gRPC client and server implementations.
// This package includes functions for building test data, logging responses, and managing common configuration.
package common

import (
	"container/list"
	"fmt"
	"hello-grpc/common/pb"
	"math/rand"
	"strconv"
	"time"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
)

// helloList contains greeting messages in multiple languages used for testing gRPC communication.
var (
	helloList = []string{"Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"}
	ansMap    = map[string]string{
		"你好":      "非常感谢",
		"Hello":   "Thank you very much",
		"Bonjour": "Merci beaucoup",
		"Hola":    "Muchas Gracias",
		"こんにちは":   "どうも ありがとう ございます",
		"Ciao":    "Mille Grazie",
		"안녕하세요":   "대단히 감사합니다",
	}
)

// GetHelloList returns a slice of greeting messages in different languages.
// These greetings are used for testing unary and streaming RPC calls.
//
// Returns:
//   - []string: A slice containing greetings in English, French, Spanish, Japanese, Italian, and Korean
//
// Example:
//
//	greetings := GetHelloList()
//	fmt.Println(greetings[0]) // Output: "Hello"
func GetHelloList() []string {
	return helloList
}

// GetAnswerMap returns a map of greetings to their corresponding thank you messages.
// This map is used by the server to respond with appropriate thank you messages
// based on the greeting received from the client.
//
// Returns:
//   - map[string]string: A map where keys are greetings and values are thank you messages
//
// Example:
//
//	answers := GetAnswerMap()
//	response := answers["Hello"] // Returns: "Thank you very much"
func GetAnswerMap() map[string]string {
	return ansMap
}

// BuildLinkRequests creates a linked list of TalkRequest objects for testing streaming RPCs.
// Each request contains a random ID and metadata identifying the language implementation.
//
// Returns:
//   - *list.List: A linked list containing 3 TalkRequest objects with random IDs
//
// Example:
//
//	requests := BuildLinkRequests()
//	for e := requests.Front(); e != nil; e = e.Next() {
//	    req := e.Value.(*pb.TalkRequest)
//	    fmt.Printf("Request: %s\n", req.Data)
//	}
func BuildLinkRequests() *list.List {
	requests := list.New()
	for i := 0; i < 3; i++ {
		requests.PushFront(&pb.TalkRequest{
			Data: RandomId(5), Meta: "GOLANG",
		})
	}
	return requests
}

// RandomId generates a random ID string between 0 and max-1.
// This function uses the current time as a seed for randomization.
//
// Parameters:
//   - max: The upper bound (exclusive) for the random number generation
//
// Returns:
//   - string: A string representation of a random integer between 0 and max-1
//
// Example:
//
//	id := RandomId(100) // Returns a string like "42" (0-99)
func RandomId(max int) string {
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	n := r.Intn(max)
	return strconv.Itoa(n)
}

// GetVersion returns the gRPC library version string.
// This is useful for debugging and ensuring version compatibility across implementations.
//
// Returns:
//   - string: A formatted string containing the gRPC version (e.g., "grpc.version=1.50.0")
//
// Example:
//
//	version := GetVersion()
//	log.Info(version) // Output: "grpc.version=1.50.0"
func GetVersion() string {
	return fmt.Sprintf("grpc.version=%s", grpc.Version)
}

// LogResponse logs the status and results of a TalkResponse in a structured format.
// This function handles nil responses gracefully and logs detailed information about
// each result in the response, including metadata and timing information.
//
// Parameters:
//   - response: The TalkResponse to log. If nil, a warning is logged.
//
// Example:
//
//	response := &pb.TalkResponse{
//	    Status: 200,
//	    Results: []*pb.TalkResult{...},
//	}
//	LogResponse(response) // Logs structured information about the response
func LogResponse(response *pb.TalkResponse) {
	if response == nil {
		log.Warn("Received nil response")
		return
	}

	resultsCount := len(response.Results)
	log.Infof("Response status: %d, results: %d", response.Status, resultsCount)

	for i, result := range response.Results {
		kv := result.Kv
		if kv == nil {
			log.Infof("  Result #%d: id=%d, type=%d, kv=nil",
				i+1, result.Id, result.Type)
			continue
		}

		meta, _ := kv["meta"]
		id, _ := kv["id"]
		idx, _ := kv["idx"]
		data, _ := kv["data"]

		log.Infof("  Result #%d: id=%d, type=%d, meta=%s, id=%s, idx=%s, data=%s",
			i+1, result.Id, result.Type, meta, id, idx, data)
	}
}
