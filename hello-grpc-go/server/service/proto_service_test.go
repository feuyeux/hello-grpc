package service

import (
	"context"
	"hello-grpc/common/pb"
	"io"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
)

// Mock gRPC server stream implementation for server streaming tests
type mockTalkOneAnswerMoreServer struct {
	grpc.ServerStream
	ctx      context.Context
	received []*pb.TalkResponse
}

func (m *mockTalkOneAnswerMoreServer) Send(response *pb.TalkResponse) error {
	m.received = append(m.received, response)
	return nil
}

func (m *mockTalkOneAnswerMoreServer) Context() context.Context {
	return m.ctx
}

// Mock gRPC client stream implementation for client streaming tests
type mockTalkMoreAnswerOneServer struct {
	grpc.ServerStream
	ctx       context.Context
	received  *pb.TalkResponse
	recvQueue []*pb.TalkRequest
	closed    bool
}

func (m *mockTalkMoreAnswerOneServer) SendAndClose(response *pb.TalkResponse) error {
	m.received = response
	return nil
}

func (m *mockTalkMoreAnswerOneServer) Recv() (*pb.TalkRequest, error) {
	if len(m.recvQueue) == 0 {
		m.closed = true
		return nil, io.EOF
	}
	req := m.recvQueue[0]
	m.recvQueue = m.recvQueue[1:]
	return req, nil
}

func (m *mockTalkMoreAnswerOneServer) Context() context.Context {
	return m.ctx
}

// Mock gRPC bidirectional stream implementation for bidirectional streaming tests
type mockTalkBidirectionalServer struct {
	grpc.ServerStream
	ctx       context.Context
	received  []*pb.TalkResponse
	recvQueue []*pb.TalkRequest
	closed    bool
}

func (m *mockTalkBidirectionalServer) Send(response *pb.TalkResponse) error {
	m.received = append(m.received, response)
	return nil
}

func (m *mockTalkBidirectionalServer) Recv() (*pb.TalkRequest, error) {
	if len(m.recvQueue) == 0 {
		m.closed = true
		return nil, io.EOF
	}
	req := m.recvQueue[0]
	m.recvQueue = m.recvQueue[1:]
	return req, nil
}

func (m *mockTalkBidirectionalServer) Context() context.Context {
	return m.ctx
}

// TestTalk tests the unary RPC Talk method
func TestTalk(t *testing.T) {
	// Create a new ProtoServer instance
	server := &ProtoServer{}

	// Create a request
	request := &pb.TalkRequest{
		Data: "1",
		Meta: "GOLANG_TEST",
	}

	// Call the service method
	response, err := server.Talk(context.Background(), request)

	// Validate the response
	assert.NoError(t, err)
	assert.Equal(t, int32(200), response.GetStatus())
	assert.Equal(t, 1, len(response.GetResults()))

	result := response.GetResults()[0]
	assert.Contains(t, result.GetKv(), "id")
	assert.Contains(t, result.GetKv(), "idx")
	assert.Contains(t, result.GetKv(), "data")
	assert.Equal(t, "1", result.GetKv()["idx"])
	assert.Equal(t, "GOLANG", result.GetKv()["meta"])
}

// TestTalkOneAnswerMore tests the server streaming RPC TalkOneAnswerMore method
func TestTalkOneAnswerMore(t *testing.T) {
	// Create a new ProtoServer instance
	server := &ProtoServer{}

	// Create a request with comma-separated values
	request := &pb.TalkRequest{
		Data: "1,2",
		Meta: "GOLANG_TEST",
	}

	// Create a mock stream
	mockStream := &mockTalkOneAnswerMoreServer{
		ctx:      context.Background(),
		received: make([]*pb.TalkResponse, 0),
	}

	// Call the service method
	err := server.TalkOneAnswerMore(request, mockStream)

	// Validate the responses
	assert.NoError(t, err)
	assert.Equal(t, 2, len(mockStream.received))

	for i, response := range mockStream.received {
		assert.Equal(t, int32(200), response.GetStatus())
		assert.Equal(t, 1, len(response.GetResults()))

		result := response.GetResults()[0]
		assert.Contains(t, result.GetKv(), "id")
		assert.Contains(t, result.GetKv(), "idx")
		assert.Contains(t, result.GetKv(), "data")

		// Index should match the position in the comma-separated input
		expectedIdx := strings.Split(request.Data, ",")[i]
		assert.Equal(t, expectedIdx, result.GetKv()["idx"])
		assert.Equal(t, "GOLANG", result.GetKv()["meta"])
	}
}

// TestTalkMoreAnswerOne tests the client streaming RPC TalkMoreAnswerOne method
func TestTalkMoreAnswerOne(t *testing.T) {
	// Create a new ProtoServer instance
	server := &ProtoServer{}

	// Create mock requests
	requests := []*pb.TalkRequest{
		{Data: "1", Meta: "GOLANG_TEST"},
		{Data: "2", Meta: "GOLANG_TEST"},
		{Data: "3", Meta: "GOLANG_TEST"},
	}

	// Create a mock stream with the requests queued
	mockStream := &mockTalkMoreAnswerOneServer{
		ctx:       context.Background(),
		recvQueue: requests,
	}

	// Call the service method
	err := server.TalkMoreAnswerOne(mockStream)

	// Validate the response
	assert.NoError(t, err)
	assert.True(t, mockStream.closed)
	assert.NotNil(t, mockStream.received)

	response := mockStream.received
	assert.Equal(t, int32(200), response.GetStatus())
	assert.Equal(t, len(requests), len(response.GetResults()))

	// Check each result corresponds to a request
	idxValues := make(map[string]bool)
	for _, result := range response.GetResults() {
		assert.Contains(t, result.GetKv(), "id")
		assert.Contains(t, result.GetKv(), "idx")
		assert.Contains(t, result.GetKv(), "data")

		// Keep track of the idx values to verify all requests were processed
		idxValues[result.GetKv()["idx"]] = true
		assert.Equal(t, "GOLANG", result.GetKv()["meta"])
	}

	// Verify all requests were processed
	for _, req := range requests {
		assert.True(t, idxValues[req.Data])
	}
}

// TestTalkBidirectional tests the bidirectional streaming RPC TalkBidirectional method
func TestTalkBidirectional(t *testing.T) {
	// Create a new ProtoServer instance
	server := &ProtoServer{}

	// Create mock requests
	requests := []*pb.TalkRequest{
		{Data: "1", Meta: "GOLANG_TEST"},
		{Data: "2", Meta: "GOLANG_TEST"},
	}

	// Create a mock stream with the requests queued
	mockStream := &mockTalkBidirectionalServer{
		ctx:       context.Background(),
		recvQueue: requests,
		received:  make([]*pb.TalkResponse, 0),
	}

	// Call the service method
	err := server.TalkBidirectional(mockStream)

	// Validate the responses
	assert.NoError(t, err)
	assert.True(t, mockStream.closed)
	assert.Equal(t, len(requests), len(mockStream.received))

	// Check each response corresponds to a request
	for i, response := range mockStream.received {
		assert.Equal(t, int32(200), response.GetStatus())
		assert.Equal(t, 1, len(response.GetResults()))

		result := response.GetResults()[0]
		assert.Contains(t, result.GetKv(), "id")
		assert.Contains(t, result.GetKv(), "idx")
		assert.Contains(t, result.GetKv(), "data")

		// Verify the idx corresponds to the request
		assert.Equal(t, requests[i].Data, result.GetKv()["idx"])
		assert.Equal(t, "GOLANG", result.GetKv()["meta"])
	}
}

// TestLogHeaders tests the logHeaders function with metadata
func TestLogHeaders(t *testing.T) {
	// Create a context with metadata
	md := metadata.Pairs(
		"x-request-id", "test-request-id",
		"test-key", "test-value",
	)
	ctx := metadata.NewIncomingContext(context.Background(), md)

	// Call the function - it only logs, so we're just ensuring it doesn't panic
	logHeaders(ctx)
}

// TestExtractTracing tests tracing data extraction
func TestExtractTracing(t *testing.T) {
	// Create a context with complete tracing metadata
	md := metadata.Pairs(
		"x-request-id", "test-request-id",
		"x-b3-traceid", "test-trace-id",
		"x-b3-spanid", "test-span-id",
		"x-b3-parentspanid", "test-parent-span-id",
		"x-b3-sampled", "1",
		"x-b3-flags", "0",
		"x-ot-span-context", "test-span-context",
	)
	ctx := metadata.NewIncomingContext(context.Background(), md)

	// Call the function
	tracingData := extractTracing(ctx)

	// Validate the extracted tracing data
	assert.NotNil(t, tracingData)
	assert.Equal(t, "test-request-id", tracingData.RequestId)
	assert.Equal(t, "test-trace-id", tracingData.B3TraceId)
	assert.Equal(t, "test-span-id", tracingData.B3SpanId)
	assert.Equal(t, "test-parent-span-id", tracingData.B3ParentSpanId)
	assert.Equal(t, "1", tracingData.B3Sampled)
	assert.Equal(t, "0", tracingData.B3Flags)
	assert.Equal(t, "test-span-context", tracingData.OtSpanContext)

	// Test with missing request ID
	md = metadata.Pairs(
		"some-key", "some-value",
	)
	ctx = metadata.NewIncomingContext(context.Background(), md)

	// Call the function with incomplete metadata
	tracingData = extractTracing(ctx)

	// Should return nil when request ID is missing
	assert.Nil(t, tracingData)
}

// TestCreateContextWithTracing tests context creation for outgoing requests
func TestCreateContextWithTracing(t *testing.T) {
	// Create a context with tracing metadata
	md := metadata.Pairs(
		"x-request-id", "test-request-id",
		"x-b3-traceid", "test-trace-id",
		"x-b3-spanid", "test-span-id",
		"x-b3-parentspanid", "test-parent-span-id",
		"x-b3-sampled", "1",
		"x-b3-flags", "0",
		"x-ot-span-context", "test-span-context",
	)
	ctx := metadata.NewIncomingContext(context.Background(), md)

	// Build a context with the tracing data
	outgoingCtx := createContextWithTracing(ctx)

	// Extract the metadata and verify the values were added
	outgoingMd, ok := metadata.FromOutgoingContext(outgoingCtx)
	assert.True(t, ok)
	assert.Equal(t, []string{"test-request-id"}, outgoingMd.Get("x-request-id"))
	assert.Equal(t, []string{"test-trace-id"}, outgoingMd.Get("x-b3-traceid"))
	assert.Equal(t, []string{"test-span-id"}, outgoingMd.Get("x-b3-spanid"))
	assert.Equal(t, []string{"test-parent-span-id"}, outgoingMd.Get("x-b3-parentspanid"))
	assert.Equal(t, []string{"1"}, outgoingMd.Get("x-b3-sampled"))
	assert.Equal(t, []string{"0"}, outgoingMd.Get("x-b3-flags"))
	assert.Equal(t, []string{"test-span-context"}, outgoingMd.Get("x-ot-span-context"))

	// Test with context without tracing metadata
	ctx = context.Background()
	outgoingCtx = createContextWithTracing(ctx)

	// Should return a blank context
	_, ok = metadata.FromOutgoingContext(outgoingCtx)
	assert.False(t, ok)
}

// TestBuildResult tests the result building function
func TestBuildResult(t *testing.T) {
	// Create a new ProtoServer instance
	server := &ProtoServer{}

	// Test result building with valid index
	result := server.buildResult("1")

	// Validate the result
	assert.NotNil(t, result)
	assert.NotZero(t, result.Id)
	assert.Equal(t, pb.ResultType_OK, result.Type)
	assert.Contains(t, result.GetKv(), "id")
	assert.NotEmpty(t, result.GetKv()["id"]) // Should contain a UUID
	assert.Equal(t, "1", result.GetKv()["idx"])
	assert.Contains(t, result.GetKv(), "data")
	assert.Equal(t, "GOLANG", result.GetKv()["meta"])

	// Test with non-numeric ID (should default to index 0)
	result = server.buildResult("non-numeric")
	assert.Equal(t, "non-numeric", result.GetKv()["idx"])
}

// TestProxyingBehavior tests the proxying behavior when a backend client is configured
func TestProxyingBehavior(t *testing.T) {
	// This test is more complex and would require mocking the gRPC client stubs
	// In a real implementation, we would use a mocking framework to mock the
	// BackendClient and verify that the proxying behavior works correctly.
	// For simplicity, we're skipping the actual implementation of this test.
	t.Skip("Proxying behavior tests would require mocking the gRPC client stubs")
}
