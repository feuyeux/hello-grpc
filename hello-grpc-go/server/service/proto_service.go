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

// ProtoServer implements LandingServiceServer interface
// This service demonstrates the four different gRPC communication patterns:
// 1. Unary RPC - Simple request/response model
// 2. Server Streaming RPC - Server sends multiple responses to a single client request
// 3. Client Streaming RPC - Client sends multiple requests and server responds with a single response
// 4. Bidirectional Streaming RPC - Both client and server send a sequence of messages
type ProtoServer struct {
	BackendClient pb.LandingServiceClient
	pb.UnimplementedLandingServiceServer
}

// Talk implements the unary RPC method.
// Handles a single request and returns a single response.
// If a backend client is configured, proxies the request to the next service.
func (s *ProtoServer) Talk(ctx context.Context, request *pb.TalkRequest) (*pb.TalkResponse, error) {
	log.Infof("TALK REQUEST: data=%s,meta=%s", request.Data, request.Meta)
	printHeaders(ctx)
	if s.BackendClient == nil {
		// No backend service, process request directly
		result := s.buildResult(request.Data)
		return &pb.TalkResponse{
			Status:  200,
			Results: []*pb.TalkResult{result},
		}, nil
	} else {
		// Proxy request to backend service
		response, err := s.BackendClient.Talk(buildContext(buildTracing(ctx)), request)
		if err != nil {
			log.Fatalf("%v.Talk(_) = _, %v", s.BackendClient, err)
		}
		return response, err
	}
}

// TalkOneAnswerMore implements the server streaming RPC method.
// Handles a single request and returns multiple responses through the stream.
// If a backend client is configured, proxies the request to the next service.
func (s *ProtoServer) TalkOneAnswerMore(request *pb.TalkRequest, stream pb.LandingService_TalkOneAnswerMoreServer) error {
	log.Infof("TalkOneAnswerMore REQUEST: data=%s,meta=%s", request.Data, request.Meta)
	ctx := stream.Context()
	printHeaders(ctx)
	if s.BackendClient == nil {
		// No backend service, process request directly
		// Split comma-separated data values and send a response for each one
		datas := strings.Split(request.Data, ",")
		for _, d := range datas {
			result := s.buildResult(d)
			if err := stream.Send(&pb.TalkResponse{
				Status:  200,
				Results: []*pb.TalkResult{result},
			}); err != nil {
				return err
			}
		}
		return nil
	} else {
		// Proxy request to backend service and forward all responses
		nextStream, err := s.BackendClient.TalkOneAnswerMore(buildContext(buildTracing(ctx)), request)
		if err != nil {
			log.Fatalf("%v.TalkOneAnswerMore(_) = _, %v", s.BackendClient, err)
			return err
		}
		for {
			r, err := nextStream.Recv()
			if err == io.EOF {
				break
			}
			if err != nil {
				log.Fatalf("%v.TalkOneAnswerMore(_) = _, %v", s.BackendClient, err)
				return err
			}
			if err := stream.Send(r); err != nil {
				return err
			}
		}
		return nil
	}
}

// TalkMoreAnswerOne implements the client streaming RPC method.
// Handles multiple requests from the client and returns a single response.
// If a backend client is configured, proxies all requests to the next service.
func (s *ProtoServer) TalkMoreAnswerOne(stream pb.LandingService_TalkMoreAnswerOneServer) error {
	ctx := stream.Context()
	if s.BackendClient == nil {
		// No backend service, process requests directly
		var rs []*pb.TalkResult
		for {
			in, err := stream.Recv()
			if err == io.EOF {
				// When client has sent all requests, combine results and send single response
				talkResponse := &pb.TalkResponse{
					Status:  200,
					Results: rs,
				}
				printHeaders(ctx)
				err := stream.SendAndClose(talkResponse)
				if err != nil {
					return err
				}
				return nil
			}
			if err != nil {
				return err
			}
			log.Infof("TalkMoreAnswerOne REQUEST: data=%s,meta=%s", in.Data, in.Meta)
			result := s.buildResult(in.Data)
			rs = append(rs, result)
		}
	} else {
		// Proxy all requests to backend service
		nextStream, err := s.BackendClient.TalkMoreAnswerOne(buildContext(buildTracing(ctx)))
		if err != nil {
			log.Fatalf("%v.TalkMoreAnswerOne(_) = _, %v", s.BackendClient, err)
			return err
		}
		for {
			request, err := stream.Recv()
			if err == io.EOF {
				printHeaders(ctx)
				talkResponse, err := nextStream.CloseAndRecv()
				if err != nil {
					log.Fatalf("%v.TalkMoreAnswerOne() got error %v, want %v", stream, err, nil)
				}
				err = stream.SendAndClose(talkResponse)
				if err != nil {
					return err
				}
				return nil
			}
			if err != nil {
				return err
			}
			log.Infof("TalkMoreAnswerOne REQUEST: data=%s,meta=%s", request.Data, request.Meta)
			if err := nextStream.Send(request); err != nil {
				log.Fatalf("%v.Send(%v) = %v", stream, request, err)
			}
		}
	}
}

// TalkBidirectional implements the bidirectional streaming RPC method.
// Handles multiple requests from the client and returns multiple responses.
// Each request receives a corresponding response.
// If a backend client is configured, proxies all requests to the next service.
func (s *ProtoServer) TalkBidirectional(stream pb.LandingService_TalkBidirectionalServer) error {
	ctx := stream.Context()
	if s.BackendClient == nil {
		// No backend service, process requests directly
		for {
			in, err := stream.Recv()
			if err == io.EOF {
				printHeaders(ctx)
				return nil
			}
			if err != nil {
				return err
			}
			log.Infof("TalkBidirectional REQUEST: data=%s,meta=%s", in.Data, in.Meta)
			// Send a response for each request received
			result := s.buildResult(in.Data)
			talkResponse := &pb.TalkResponse{
				Status:  200,
				Results: []*pb.TalkResult{result},
			}
			if err := stream.Send(talkResponse); err != nil {
				return err
			}
		}
	} else {
		// Proxy all requests to backend service
		nextStream, err := s.BackendClient.TalkBidirectional(buildContext(buildTracing(ctx)))
		if err != nil {
			log.Fatalf("%v Request Next TalkBidirectional failed:%v", s.BackendClient, err)
			return err
		}
		waitc := make(chan struct{})
		// Goroutine to receive responses from backend service and forward them to client
		go func() {
			for {
				r, err := nextStream.Recv()
				if err == io.EOF {
					time.Sleep(1 * time.Second)
					printHeaders(ctx)
					close(waitc)
					return
				}
				if err != nil {
					log.Fatalf("Failed to receive a note : %v", err)
				}
				if err := stream.Send(r); err != nil {
					log.Fatalf("%v.TalkBidirectional send back failed, %v", s.BackendClient, err)
				}
			}
		}()
		// Receive requests from client and forward them to backend service
		for {
			in, err := stream.Recv()
			if err == io.EOF {
				time.Sleep(1 * time.Second)
				break
			}
			if err != nil {
				log.Fatalf("Failed to receive from Previous: %v", err)
				break
			}
			log.Infof("TalkBidirectional REQUEST: data=%s,meta=%s", in.Data, in.Meta)
			if err := nextStream.Send(in); err != nil {
				log.Fatalf("Failed to send : %v", err)
			}
		}
		err = nextStream.CloseSend()
		if err != nil {
			return err
		}
		<-waitc
		return nil
	}
}

// buildResult creates a TalkResult object containing the response data.
// Parameters:
//   - id: The request ID (typically a language index)
//
// Returns: A TalkResult with timestamp, type and key-value data
func (s *ProtoServer) buildResult(id string) *pb.TalkResult {
	index, _ := strconv.Atoi(id)
	kv := make(map[string]string)
	kv["id"] = uuid.New().String()
	kv["idx"] = id
	hello := common.GetHelloList()[index]
	kv["data"] = hello + "," + common.GetAnswerMap()[hello]
	kv["meta"] = "GOLANG"
	result := new(pb.TalkResult)
	result.Id = time.Now().UnixNano()
	result.Type = pb.ResultType_OK
	result.Kv = kv
	return result
}

// buildContext creates a new context with tracing metadata for outgoing requests.
// Parameters:
//   - headerTracing: Tracing information to propagate
//
// Returns: A context with tracing metadata appended
func buildContext(headerTracing *tracing.HelloTracing) context.Context {
	var ctx context.Context
	if headerTracing != nil {
		ctx = metadata.AppendToOutgoingContext(context.Background(), headerTracing.Kv()...)
	} else {
		ctx = context.Background()
	}
	return ctx
}

// buildTracing extracts tracing information from the incoming request context.
// Parameters:
//   - ctx: The incoming request context
//
// Returns: A HelloTracing object containing the extracted tracing data
func buildTracing(ctx context.Context) *tracing.HelloTracing {
	md, ok := metadata.FromIncomingContext(ctx)
	if ok {
		xRequestId := md.Get("x-request-id")
		if xRequestId != nil && len(xRequestId) > 0 {
			xB3TraceId := md.Get("x-b3-traceid")
			xB3SpanId := md.Get("x-b3-spanid")
			xB3ParentSpanId := md.Get("x-b3-parentspanid")
			xB3Sampled := md.Get("x-b3-sampled")
			xB3Flags := md.Get("x-b3-flags")
			xOtSpanContext := md.Get("x-ot-span-context")
			log.Infof("TALK HEADERS: "+
				"x_request_id=%v,"+
				"x_b3_traceid=%v,"+
				"x_b3_spanid=%v,"+
				"x_b3_parentspanid=%v,"+
				"x_b3_sampled=%v,"+
				"x_b3_flags=%v,"+
				"x_ot_span_context=%v",
				xRequestId, xB3TraceId, xB3SpanId, xB3ParentSpanId, xB3Sampled, xB3Flags, xOtSpanContext)
			t := &tracing.HelloTracing{
				RequestId:      xRequestId[0],
				B3TraceId:      xB3TraceId[0],
				B3SpanId:       xB3SpanId[0],
				B3ParentSpanId: xB3ParentSpanId[0],
				B3Sampled:      xB3Sampled[0],
			}
			if xB3Flags != nil {
				t.B3Flags = xB3Flags[0]
			}
			if xOtSpanContext != nil {
				t.OtSpanContext = xOtSpanContext[0]
			}
			return t
		}
	}
	return nil
}

// printHeaders logs all headers from the incoming request context.
// Parameters:
//   - ctx: The incoming request context
func printHeaders(ctx context.Context) {
	md, ok := metadata.FromIncomingContext(ctx)
	if ok {
		for key, value := range md {
			log.Infof("->H %s:%s", key, value)
		}
	}
}
