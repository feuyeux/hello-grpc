package server

import (
	"context"
	"io"
	"strconv"
	"strings"
	"time"

	"github.com/feuyeux/hello-grpc-go/common/pb"
	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc/metadata"
)

var (
	helloList = []string{"Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"}
)

//implement LandingServiceServer interface
type ProtoServer struct {
	BackendClient pb.LandingServiceClient
}

func (s *ProtoServer) Talk(ctx context.Context, request *pb.TalkRequest) (*pb.TalkResponse, error) {
	log.Infof("TALK REQUEST: data=%s,meta=%s", request.Data, request.Meta)
	if s.BackendClient == nil {
		result := s.buildResult(request.Data)
		return &pb.TalkResponse{
			Status:  200,
			Results: []*pb.TalkResult{result},
		}, nil
	} else {
		response, err := s.BackendClient.Talk(buildContext(buildTracing(ctx)), request)
		if err != nil {
			log.Fatalf("%v.Talk(_) = _, %v", s.BackendClient, err)
		}
		return response, err
	}
}

func (s *ProtoServer) TalkOneAnswerMore(request *pb.TalkRequest, stream pb.LandingService_TalkOneAnswerMoreServer) error {
	log.Infof("TalkOneAnswerMore REQUEST: data=%s,meta=%s", request.Data, request.Meta)
	if s.BackendClient == nil {
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
		stream2, err := s.BackendClient.TalkOneAnswerMore(buildContext(buildTracing(stream.Context())), request)
		if err != nil {
			log.Fatalf("%v.TalkOneAnswerMore(_) = _, %v", s.BackendClient, err)
			return err
		}
		for {
			r, err := stream2.Recv()
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

func (s *ProtoServer) TalkMoreAnswerOne(stream pb.LandingService_TalkMoreAnswerOneServer) error {
	if s.BackendClient == nil {
		var rs []*pb.TalkResult
		for {
			in, err := stream.Recv()
			if err == io.EOF {
				talkResponse := &pb.TalkResponse{
					Status:  200,
					Results: rs,
				}
				stream.SendAndClose(talkResponse)
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
		stream2, err := s.BackendClient.TalkMoreAnswerOne(buildContext(buildTracing(stream.Context())))
		if err != nil {
			log.Fatalf("%v.TalkMoreAnswerOne(_) = _, %v", s.BackendClient, err)
			return err
		}
		for {
			in, err := stream.Recv()
			if err == io.EOF {
				break
			}
			if err != nil {
				return err
			}
			log.Infof("TalkMoreAnswerOne REQUEST: data=%s,meta=%s", in.Data, in.Meta)
			if err := stream2.Send(in); err != nil {
				log.Fatalf("%v.Send(%v) = %v", stream, in, err)
			}
		}
		talkResponse, err := stream2.CloseAndRecv()
		if err != nil {
			log.Fatalf("%v.TalkMoreAnswerOne() got error %v, want %v", stream, err, nil)
		}
		stream.SendAndClose(talkResponse)
		return nil
	}
}

func (s *ProtoServer) TalkBidirectional(stream pb.LandingService_TalkBidirectionalServer) error {
	if s.BackendClient == nil {
		for {
			in, err := stream.Recv()
			if err == io.EOF {
				return nil
			}
			if err != nil {
				return err
			}
			log.Infof("TalkBidirectional REQUEST: data=%s,meta=%s", in.Data, in.Meta)
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
		stream2, err := s.BackendClient.TalkBidirectional(buildContext(buildTracing(stream.Context())))
		if err != nil {
			log.Fatalf("%v Request Next TalkBidirectional failed:%v", s.BackendClient, err)
			return err
		}
		waitc := make(chan struct{})
		go func() {
			for {
				r, err := stream2.Recv()
				if err == io.EOF {
					time.Sleep(1 * time.Second)
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
			if err := stream2.Send(in); err != nil {
				log.Fatalf("Failed to send : %v", err)
			}
		}
		stream2.CloseSend()
		<-waitc
		return nil
	}
}

func (s *ProtoServer) buildResult(id string) *pb.TalkResult {
	index, _ := strconv.Atoi(id)
	kv := make(map[string]string)
	kv["id"] = uuid.New().String()
	kv["idx"] = id
	kv["data"] = helloList[index]
	kv["meta"] = "GOLANG"
	result := new(pb.TalkResult)
	result.Id = time.Now().UnixNano()
	result.Type = pb.ResultType_OK
	result.Kv = kv
	return result
}

func buildContext(headerTracing *HelloTracing) context.Context {
	var ctx context.Context
	if headerTracing != nil {
		ctx = metadata.AppendToOutgoingContext(context.Background(), headerTracing.kv()...)
	} else {
		ctx = context.Background()
	}
	return ctx
}

func buildTracing(ctx context.Context) *HelloTracing {
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
			tracing := &HelloTracing{
				xRequestId:      xRequestId[0],
				xB3TraceId:      xB3TraceId[0],
				xB3SpanId:       xB3SpanId[0],
				xB3ParentSpanId: xB3ParentSpanId[0],
				xB3Sampled:      xB3Sampled[0],
			}
			if xB3Flags != nil {
				tracing.xB3Flags = xB3Flags[0]
			}
			if xOtSpanContext != nil {
				tracing.xOtSpanContext = xOtSpanContext[0]
			}
			return tracing
		}
	}
	return nil
}
