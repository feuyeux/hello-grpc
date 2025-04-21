package conn

import (
	"context"
	"fmt"
	"google.golang.org/grpc/stats"
	"log"
)

type StatsHandler struct {
}

// TagConn TagConn可以将一些信息附加到给定的上下文。
func (h *StatsHandler) TagConn(ctx context.Context, info *stats.ConnTagInfo) context.Context {
	fmt.Println("tagConn...")
	return ctx
}

// 会在连接开始和结束时被调用，分别会输入不同的状态.

func (h *StatsHandler) HandleConn(ctx context.Context, s stats.ConnStats) {
	// 开始和结束状态
	switch s.(type) {
	case *stats.ConnBegin:
		log.Printf("begin conn")
	case *stats.ConnEnd:
		log.Printf("end conn")
	default:
		fmt.Println("handleConn...")
	}
}

// TagRPC可以将一些信息附加到给定的上下文

func (h *StatsHandler) TagRPC(ctx context.Context, info *stats.RPCTagInfo) context.Context {
	fmt.Println("tagrpc...@" + info.FullMethodName)
	return ctx
}

// HandleRPC 处理RPC统计信息
func (h *StatsHandler) HandleRPC(ctx context.Context, s stats.RPCStats) {
	switch s.(type) {
	case *stats.Begin:
		fmt.Println("handlerRPC begin...")
	case *stats.End:
		fmt.Println("handlerRPC End...")
	case *stats.InHeader:
		fmt.Println("handlerRPC InHeader...")
	case *stats.InPayload:
		fmt.Println("handlerRPC InPayload...")
	case *stats.InTrailer:
		fmt.Println("handlerRPC InTrailer...")
	case *stats.OutHeader:
		fmt.Println("handlerRPC OutHeader...")
	case *stats.OutPayload:
		fmt.Println("handlerRPC OutPayload...")
	default:
		fmt.Println("handleRPC...")
	}
}
