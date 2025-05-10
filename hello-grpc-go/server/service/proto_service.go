package service

import (
	"context"
	"hello-grpc/common"
	"io"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc/metadata"
	"hello-grpc/common/pb"
	"hello-grpc/server/tracing"
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
	log.Infof("TALK REQUEST: data=%s, meta=%s", request.Data, request.Meta)
	logHeaders(ctx)

	if s.BackendClient == nil {
		// Process request locally
		result := s.buildResult(request.Data)
		return &pb.TalkResponse{
			Status:  200,
			Results: []*pb.TalkResult{result},
		}, nil
	}

	// Forward request to backend service
	response, err := s.BackendClient.Talk(createContextWithTracing(ctx), request)
	if err != nil {
		log.Errorf("%v.Talk(_) = _, %v", s.BackendClient, err)
	}
	return response, err
}

// TalkOneAnswerMore implements the server streaming RPC method.
// Receives a single request and sends multiple responses through the stream.
func (s *ProtoServer) TalkOneAnswerMore(request *pb.TalkRequest, stream pb.LandingService_TalkOneAnswerMoreServer) error {
	log.Infof("TalkOneAnswerMore REQUEST: data=%s, meta=%s", request.Data, request.Meta)
	ctx := stream.Context()
	logHeaders(ctx)

	if s.BackendClient == nil {
		// Process request locally
		dataItems := strings.Split(request.Data, ",")
		for _, item := range dataItems {
			result := s.buildResult(item)
			if err := stream.Send(&pb.TalkResponse{
				Status:  200,
				Results: []*pb.TalkResult{result},
			}); err != nil {
				return err
			}
		}
		return nil
	}

	// Forward request to backend service
	nextStream, err := s.BackendClient.TalkOneAnswerMore(createContextWithTracing(ctx), request)
	if err != nil {
		log.Errorf("%v.TalkOneAnswerMore(_) = _, %v", s.BackendClient, err)
		return err
	}

	// Forward all responses from backend to client
	for {
		response, err := nextStream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Errorf("%v.TalkOneAnswerMore(_) = _, %v", s.BackendClient, err)
			return err
		}
		if err := stream.Send(response); err != nil {
			return err
		}
	}
	return nil
}

// TalkMoreAnswerOne implements the client streaming RPC method.
// Receives multiple requests from client and returns a single response.
func (s *ProtoServer) TalkMoreAnswerOne(stream pb.LandingService_TalkMoreAnswerOneServer) error {
	ctx := stream.Context()

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
				return err
			}
			log.Infof("TalkMoreAnswerOne REQUEST: data=%s, meta=%s", request.Data, request.Meta)
			result := s.buildResult(request.Data)
			results = append(results, result)
		}
	}

	// Forward requests to backend service
	nextStream, err := s.BackendClient.TalkMoreAnswerOne(createContextWithTracing(ctx))
	if err != nil {
		log.Errorf("%v.TalkMoreAnswerOne(_) = _, %v", s.BackendClient, err)
		return err
	}

	// Forward all client requests to backend
	for {
		request, err := stream.Recv()
		if err == io.EOF {
			logHeaders(ctx)
			response, err := nextStream.CloseAndRecv()
			if err != nil {
				log.Errorf("Error receiving response from backend: %v", err)
				return err
			}
			return stream.SendAndClose(response)
		}
		if err != nil {
			return err
		}
		log.Infof("TalkMoreAnswerOne REQUEST: data=%s, meta=%s", request.Data, request.Meta)
		if err := nextStream.Send(request); err != nil {
			log.Errorf("Failed to forward request: %v", err)
			return err
		}
	}
}

// TalkBidirectional implements the bidirectional streaming RPC method.
// Handles multiple requests and returns multiple responses in a stream.
func (s *ProtoServer) TalkBidirectional(stream pb.LandingService_TalkBidirectionalServer) error {
	ctx := stream.Context()

	if s.BackendClient == nil {
		// Process requests locally
		for {
			request, err := stream.Recv()
			if err == io.EOF {
				logHeaders(ctx)
				return nil
			}
			if err != nil {
				return err
			}
			log.Infof("TalkBidirectional REQUEST: data=%s, meta=%s", request.Data, request.Meta)

			// Send response for each request
			result := s.buildResult(request.Data)
			response := &pb.TalkResponse{
				Status:  200,
				Results: []*pb.TalkResult{result},
			}
			if err := stream.Send(response); err != nil {
				return err
			}
		}
	}

	// Forward requests to backend service
	nextStream, err := s.BackendClient.TalkBidirectional(createContextWithTracing(ctx))
	if err != nil {
		log.Errorf("Failed to connect to backend service: %v", err)
		return err
	}

	// Channel to signal when response handling is done
	done := make(chan struct{})

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
				log.Errorf("Failed to receive response from backend: %v", err)
				return
			}
			if err := stream.Send(response); err != nil {
				log.Errorf("Failed to forward response to client: %v", err)
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
			log.Errorf("Failed to receive request from client: %v", err)
			break
		}
		log.Infof("TalkBidirectional REQUEST: data=%s, meta=%s", request.Data, request.Meta)
		if err := nextStream.Send(request); err != nil {
			log.Errorf("Failed to forward request to backend: %v", err)
			break
		}
	}

	if err := nextStream.CloseSend(); err != nil {
		return err
	}

	<-done
	return nil
}

// buildResult creates a TalkResult object with the given ID.
func (s *ProtoServer) buildResult(id string) *pb.TalkResult {
	index, _ := strconv.Atoi(id)
	kv := make(map[string]string)
	kv["id"] = uuid.New().String()
	kv["idx"] = id
	hello := common.GetHelloList()[index]
	kv["data"] = hello + "," + common.GetAnswerMap()[hello]
	kv["meta"] = "GOLANG"

	return &pb.TalkResult{
		Id:   time.Now().UnixNano(),
		Type: pb.ResultType_OK,
		Kv:   kv,
	}
}

// createContextWithTracing creates a context with tracing metadata.
func createContextWithTracing(ctx context.Context) context.Context {
	headerTracing := extractTracing(ctx)
	if headerTracing != nil {
		return metadata.AppendToOutgoingContext(context.Background(), headerTracing.Kv()...)
	}
	return context.Background()
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

	t := &tracing.HelloTracing{
		RequestId:      xRequestId[0],
		B3TraceId:      xB3TraceId[0],
		B3SpanId:       xB3SpanId[0],
		B3ParentSpanId: xB3ParentSpanId[0],
		B3Sampled:      xB3Sampled[0],
	}

	if xB3Flags != nil && len(xB3Flags) > 0 {
		t.B3Flags = xB3Flags[0]
	}
	if xOtSpanContext != nil && len(xOtSpanContext) > 0 {
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
