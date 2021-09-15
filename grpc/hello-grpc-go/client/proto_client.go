package main

import (
	"io"
	"math/rand"
	"strconv"
	"time"

	"github.com/feuyeux/hello-grpc-go/common/pb"
	"github.com/feuyeux/hello-grpc-go/conn"
	log "github.com/sirupsen/logrus"
	"golang.org/x/net/context"
	"google.golang.org/grpc/metadata"
)

func main() {
	conn, err := conn.Dial()
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()
	c := pb.NewLandingServiceClient(conn)
	log.Infof("Unary RPC")
	talk(c, &pb.TalkRequest{Data: "0", Meta: "GOLANG"})
	log.Infof("Server streaming RPC")
	talkOneAnswerMore(c, &pb.TalkRequest{Data: "0,1,2", Meta: "GOLANG"})
	log.Infof("Client streaming RPC")
	requests := []*pb.TalkRequest{
		{Data: randomId(5), Meta: "GOLANG"},
		{Data: randomId(5), Meta: "GOLANG"},
		{Data: randomId(5), Meta: "GOLANG"}}
	talkMoreAnswerOne(c, requests)
	log.Infof("Bidirectional streaming RPC")
	talkBidirectional(c, requests)
}

func talk(client pb.LandingServiceClient, request *pb.TalkRequest) {
	log.Infof("Request=%+v", request)
	ctx := metadata.AppendToOutgoingContext(context.Background(), "k1", "v1", "k2", "v2")
	r, err := client.Talk(ctx, request)
	if err != nil {
		log.Fatalf("fail to talk: %v", err)
	}
	printResponse(r)
	//b, err := json.Marshal(r)
	//log.Infof("Response=%+v", string(b))
}

func talkOneAnswerMore(client pb.LandingServiceClient, request *pb.TalkRequest) {
	log.Infof("Request=%+v", request)
	ctx := metadata.AppendToOutgoingContext(context.Background(), "k1", "v1", "k2", "v2")
	stream, err := client.TalkOneAnswerMore(ctx, request)
	if err != nil {
		log.Fatalf("%v.TalkOneAnswerMore(_) = _, %v", client, err)
	}
	for {
		r, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Fatalf("%v.TalkOneAnswerMore(_) = _, %v", client, err)
		}
		printResponse(r)
	}
}
func talkMoreAnswerOne(client pb.LandingServiceClient, requests []*pb.TalkRequest) {
	ctx := metadata.AppendToOutgoingContext(context.Background(), "k1", "v1", "k2", "v2")
	stream, err := client.TalkMoreAnswerOne(ctx)
	if err != nil {
		log.Fatalf("%v.TalkMoreAnswerOne(_) = _, %v", client, err)
	}
	for _, request := range requests {
		log.Infof("Request=%+v", request)
		if err := stream.Send(request); err != nil {
			log.Fatalf("%v.Send(%v) = %v", stream, request, err)
		}
	}
	r, err := stream.CloseAndRecv()
	if err != nil {
		log.Fatalf("%v.TalkMoreAnswerOne() got error %v, want %v", stream, err, nil)
	}
	printResponse(r)
}

func talkBidirectional(client pb.LandingServiceClient, requests []*pb.TalkRequest) {
	ctx := metadata.AppendToOutgoingContext(context.Background(), "k1", "v1", "k2", "v2")
	stream, err := client.TalkBidirectional(ctx)
	if err != nil {
		log.Fatalf("%v.TalkBidirectional(_) = _, %v", client, err)
	}
	waitc := make(chan struct{})
	go func() {
		for {
			r, err := stream.Recv()
			if err == io.EOF {
				// read done.
				close(waitc)
				return
			}
			if err != nil {
				log.Fatalf("Failed to receive a note : %v", err)
			}
			printResponse(r)
		}
	}()
	for _, request := range requests {
		log.Infof("Request=%+v", request)
		if err := stream.Send(request); err != nil {
			log.Fatalf("Failed to send : %v", err)
		}
		time.Sleep(2 * time.Millisecond)
	}
	stream.CloseSend()
	<-waitc
}

func randomId(max int) string {
	return strconv.Itoa(rand.Intn(max))
}

func printResponse(response *pb.TalkResponse) {
	for _, result := range response.Results {
		kv := result.Kv
		log.Infof("[%d] %d [%s %+v %s,%s:%s]",
			response.Status, result.Id, kv["meta"], result.Type, kv["id"], kv["idx"], kv["data"])
	}
}
