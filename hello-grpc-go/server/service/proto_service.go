package service

import (
	"context"
	"hello-grpc/common"
	"io"
	"strconv"
	"strings"
	"time"

	"hello-grpc/common/pb"
	"hello-grpc/server/tracing"

	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// ProtoServer implements the LandingServiceServer interface.
// It demonstrates four gRPC communication patterns:
// 1. Unary RPC (Talk)
// 2. Server Streaming RPC (TalkOneAnswerMore)
// 3. Client Streaming RPC (TalkMoreAnswerOne)
// 4. Bidirectional Streaming RPC (TalkBidirectional)
type ProtoServer struct {
	BackendClient pb.LandingServiceClient
	pb.UnimplementedLandingServiceServer
}

// Talk implements the unary RPC method.
// Receives a single request and returns a single response.
func (s *ProtoServer) Talk(ctx context.Context, request *pb.TalkRequest) (*pb.TalkResponse, error) {
	common.RecordRpcCall(ctx, "Talk")
	requestID := common.ExtractRequestID(ctx)
	log.Infof("TALK REQUEST: data=%s, meta=%s", request.Data, request.Meta)
	logHeaders(ctx)

	if s.BackendClient == nil {
		// Process request locally
		result, err := s.buildResult(request.Data)
		if err != nil {
			return nil, err
		}
		return &pb.TalkResponse{
			Status:  200,
			Results: []*pb.TalkResult{result},
		}, nil
	}

	// Forward request to backend service
	response, err := s.BackendClient.Talk(createContextWithTracing(ctx), request)
	if err != nil {
		common.LogError(err, requestID, "Talk")
		return nil, common.ToGrpcError(err, requestID)
	}
	return response, nil
}

// TalkOneAnswerMore implements the server streaming RPC method.
// Receives a single request and sends multiple responses through the stream.
func (s *ProtoServer) TalkOneAnswerMore(request *pb.TalkRequest, stream pb.LandingService_TalkOneAnswerMoreServer) error {
	ctx := stream.Context()
	common.RecordRpcCall(ctx, "TalkOneAnswerMore")
	requestID := common.ExtractRequestID(ctx)
	log.Infof("TalkOneAnswerMore REQUEST: data=%s, meta=%s", request.Data, request.Meta)
	logHeaders(ctx)

	if s.BackendClient == nil {
		// Process request locally
		dataItems := strings.Split(request.Data, ",")
		for _, item := range dataItems {
			result, err := s.buildResult(item)
			if err != nil {
				return err
			}
			if err := stream.Send(&pb.TalkResponse{
				Status:  200,
				Results: []*pb.TalkResult{result},
			}); err != nil {
				common.LogError(err, requestID, "TalkOneAnswerMore.Send")
				return common.ToGrpcError(err, requestID)
			}
		}
		return nil
	}

	// Forward request to backend service
	nextStream, err := s.BackendClient.TalkOneAnswerMore(createContextWithTracing(ctx), request)
	if err != nil {
		common.LogError(err, requestID, "TalkOneAnswerMore")
		return common.ToGrpcError(err, requestID)
	}

	// Forward all responses from backend to client
	for {
		response, err := nextStream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			common.LogError(err, requestID, "TalkOneAnswerMore.Recv")
			return common.ToGrpcError(err, requestID)
		}
		if err := stream.Send(response); err != nil {
			common.LogError(err, requestID, "TalkOneAnswerMore.Send")
			return common.ToGrpcError(err, requestID)
		}
	}
	return nil
}

// TalkMoreAnswerOne implements the client streaming RPC method.
// Receives multiple requests from client and returns a single response.
func (s *ProtoServer) TalkMoreAnswerOne(stream pb.LandingService_TalkMoreAnswerOneServer) error {
	ctx := stream.Context()
	common.RecordRpcCall(ctx, "TalkMoreAnswerOne")
	requestID := common.ExtractRequestID(ctx)

	if s.BackendClient == nil {
		// Process requests locally
		var results []*pb.TalkResult
		for {
			request, err := stream.Recv()
			if err == io.EOF {
				// Client finished sending requests, send combined response
				response := &pb.TalkResponse{
					Status:  200,
					Results: results,
				}
				logHeaders(ctx)
				return stream.SendAndClose(response)
			}
			if err != nil {
				common.LogError(err, requestID, "TalkMoreAnswerOne.Recv")
				return common.ToGrpcError(err, requestID)
			}
			log.Infof("TalkMoreAnswerOne REQUEST: data=%s, meta=%s", request.Data, request.Meta)
			result, err := s.buildResult(request.Data)
			if err != nil {
				return err
			}
			results = append(results, result)
		}
	}

	// Forward requests to backend service
	nextStream, err := s.BackendClient.TalkMoreAnswerOne(createContextWithTracing(ctx))
	if err != nil {
		common.LogError(err, requestID, "TalkMoreAnswerOne")
		return common.ToGrpcError(err, requestID)
	}

	// Forward all client requests to backend
	for {
		request, err := stream.Recv()
		if err == io.EOF {
			logHeaders(ctx)
			response, err := nextStream.CloseAndRecv()
			if err != nil {
				common.LogError(err, requestID, "TalkMoreAnswerOne.CloseAndRecv")
				return common.ToGrpcError(err, requestID)
			}
			return stream.SendAndClose(response)
		}
		if err != nil {
			common.LogError(err, requestID, "TalkMoreAnswerOne.Recv")
			return common.ToGrpcError(err, requestID)
		}
		log.Infof("TalkMoreAnswerOne REQUEST: data=%s, meta=%s", request.Data, request.Meta)
		if err := nextStream.Send(request); err != nil {
			common.LogError(err, requestID, "TalkMoreAnswerOne.Send")
			return common.ToGrpcError(err, requestID)
		}
	}
}

// TalkBidirectional implements the bidirectional streaming RPC method.
// Handles multiple requests and returns multiple responses in a stream.
func (s *ProtoServer) TalkBidirectional(stream pb.LandingService_TalkBidirectionalServer) error {
	ctx := stream.Context()
	common.RecordRpcCall(ctx, "TalkBidirectional")
	requestID := common.ExtractRequestID(ctx)

	if s.BackendClient == nil {
		// Process requests locally
		for {
			request, err := stream.Recv()
			if err == io.EOF {
				logHeaders(ctx)
				return nil
			}
			if err != nil {
				common.LogError(err, requestID, "TalkBidirectional.Recv")
				return common.ToGrpcError(err, requestID)
			}
			log.Infof("TalkBidirectional REQUEST: data=%s, meta=%s", request.Data, request.Meta)

			// Send response for each request
			result, err := s.buildResult(request.Data)
			if err != nil {
				return err
			}
			response := &pb.TalkResponse{
				Status:  200,
				Results: []*pb.TalkResult{result},
			}
			if err := stream.Send(response); err != nil {
				common.LogError(err, requestID, "TalkBidirectional.Send")
				return common.ToGrpcError(err, requestID)
			}
		}
	}

	// Forward requests to backend service
	nextStream, err := s.BackendClient.TalkBidirectional(createContextWithTracing(ctx))
	if err != nil {
		common.LogError(err, requestID, "TalkBidirectional")
		return common.ToGrpcError(err, requestID)
	}

	// Channel to signal when response handling is done
	done := make(chan struct{})
	errChan := make(chan error, 1)

	// Goroutine to handle responses from backend service
	go func() {
		for {
			response, err := nextStream.Recv()
			if err == io.EOF {
				logHeaders(ctx)
				close(done)
				return
			}
			if err != nil {
				common.LogError(err, requestID, "TalkBidirectional.Recv")
				errChan <- common.ToGrpcError(err, requestID)
				return
			}
			if err := stream.Send(response); err != nil {
				common.LogError(err, requestID, "TalkBidirectional.Send")
				errChan <- common.ToGrpcError(err, requestID)
				return
			}
		}
	}()

	// Handle requests from client and forward to backend
	for {
		request, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			common.LogError(err, requestID, "TalkBidirectional.Recv")
			return common.ToGrpcError(err, requestID)
		}
		log.Infof("TalkBidirectional REQUEST: data=%s, meta=%s", request.Data, request.Meta)
		if err := nextStream.Send(request); err != nil {
			common.LogError(err, requestID, "TalkBidirectional.Send")
			return common.ToGrpcError(err, requestID)
		}
	}

	if err := nextStream.CloseSend(); err != nil {
		common.LogError(err, requestID, "TalkBidirectional.CloseSend")
		return common.ToGrpcError(err, requestID)
	}

	// Wait for response handling to complete or error
	select {
	case <-done:
		return nil
	case err := <-errChan:
		return err
	}
}

// buildResult creates a TalkResult object with the given ID.
func (s *ProtoServer) buildResult(id string) (*pb.TalkResult, error) {
	index, err := strconv.Atoi(id)
	hellos := common.GetHelloList()
	if err != nil || index < 0 || index >= len(hellos) {
		return nil, status.Errorf(codes.InvalidArgument, "data must be an integer between 0 and %d", len(hellos)-1)
	}
	kv := make(map[string]string)
	kv["id"] = uuid.New().String()
	kv["idx"] = id
	hello := hellos[index]
	kv["data"] = hello + "," + common.GetAnswerMap()[hello]
	kv["meta"] = "GOLANG"

	return &pb.TalkResult{
		Id:   time.Now().UnixNano(),
		Type: pb.ResultType_OK,
		Kv:   kv,
	}, nil
}

// createContextWithTracing creates a context with tracing metadata.
func createContextWithTracing(ctx context.Context) context.Context {
	headerTracing := extractTracing(ctx)
	if headerTracing != nil {
		return metadata.AppendToOutgoingContext(ctx, headerTracing.Kv()...)
	}
	return ctx
}

// extractTracing extracts tracing information from the context.
func extractTracing(ctx context.Context) *tracing.HelloTracing {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return nil
	}

	xRequestId := md.Get("x-request-id")
	if xRequestId == nil || len(xRequestId) == 0 {
		return nil
	}

	xB3TraceId := md.Get("x-b3-traceid")
	xB3SpanId := md.Get("x-b3-spanid")
	xB3ParentSpanId := md.Get("x-b3-parentspanid")
	xB3Sampled := md.Get("x-b3-sampled")
	xB3Flags := md.Get("x-b3-flags")
	xOtSpanContext := md.Get("x-ot-span-context")

	log.Infof("TRACING HEADERS: x_request_id=%v, x_b3_traceid=%v, x_b3_spanid=%v",
		xRequestId, xB3TraceId, xB3SpanId)

	first := func(values []string) string {
		if len(values) == 0 {
			return ""
		}
		return values[0]
	}

	t := &tracing.HelloTracing{
		RequestId:      first(xRequestId),
		B3TraceId:      first(xB3TraceId),
		B3SpanId:       first(xB3SpanId),
		B3ParentSpanId: first(xB3ParentSpanId),
		B3Sampled:      first(xB3Sampled),
	}

	if len(xB3Flags) > 0 {
		t.B3Flags = xB3Flags[0]
	}
	if len(xOtSpanContext) > 0 {
		t.OtSpanContext = xOtSpanContext[0]
	}

	return t
}

// logHeaders logs metadata headers from the context.
func logHeaders(ctx context.Context) {
	md, ok := metadata.FromIncomingContext(ctx)
	if ok {
		for key, value := range md {
			log.Infof("Header: %s:%s", key, value)
		}
	}
}
