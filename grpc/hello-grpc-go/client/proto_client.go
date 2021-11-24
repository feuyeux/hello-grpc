package main

import (
	"io"
	"math/rand"
	"strconv"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
	"golang.org/x/net/context"
	"google.golang.org/grpc/metadata"
	"hello-grpc/common/pb"
	"hello-grpc/conn"
)

func main() {
	con, err := conn.Dial()
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer con.Close()
	c := pb.NewLandingServiceClient(con)
	log.Infof("Unary RPC")
	talk(c, &pb.TalkRequest{Data: "0", Meta: "GOLANG"})
	log.Infof("Server streaming RPC")
	talkOneAnswerMore(c, &pb.TalkRequest{Data: "0,1,2", Meta: "GOLANG"})

	requests := []*pb.TalkRequest{
		{Data: randomId(5), Meta: "GOLANG"},
		{Data: randomId(5), Meta: "GOLANG"},
		{Data: randomId(5), Meta: "GOLANG"}}

	respChan := make(chan *pb.TalkResponse)
	log.Infof("Client streaming RPC")
	go func() {
		r, err := talkMoreAnswerOne(c, requests)
		if err != nil {
			log.Fatalf("TalkMoreAnswerOne() got error %v", err)
			respChan <- nil
		} else {
			respChan <- r
			close(respChan)
		}
	}()
	for r := range respChan {
		printResponse(r)
	}

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

func talkMoreAnswerOne(client pb.LandingServiceClient, requests []*pb.TalkRequest) (*pb.TalkResponse, error) {
	ctx := metadata.AppendToOutgoingContext(context.Background(), "k1", "v1", "k2", "v2")
	stream, err := client.TalkMoreAnswerOne(ctx)
	if err != nil {
		log.Fatalf("%v.TalkMoreAnswerOne(_) = _, %v", client, err)
	}
	//
	var wg sync.WaitGroup
	wg.Add(len(requests))
	for i := 0; i < len(requests); i++ {
		request := requests[i]
		go func(i int) {
			defer wg.Done()
			log.Infof("Request[%d]=%+v", i, request)
			if err := stream.Send(request); err != nil {
				log.Fatalf("%v.Send(%v) = %v", stream, request, err)
			}
		}(i)
	}
	wg.Wait()
	//
	return stream.CloseAndRecv()
}

func talkBidirectional(client pb.LandingServiceClient, requests []*pb.TalkRequest) {
	ctx := metadata.AppendToOutgoingContext(context.Background(), "k1", "v1", "k2", "v2")
	stream, err := client.TalkBidirectional(ctx)
	if err != nil {
		log.Fatalf("%v.TalkBidirectional(_) = _, %v", client, err)
	}
	waits := make(chan struct{})
	go func() {
		for {
			r, err := stream.Recv()
			if err == io.EOF {
				// read done.
				close(waits)
				return
			}
			if err != nil {
				log.Fatalf("Failed to receive a note : %v", err)
			}
			printResponse(r)
		}
	}()
	//
	for _, request := range requests {
		log.Infof("Request=%+v", request)
		if err := stream.Send(request); err != nil {
			log.Fatalf("Failed to send : %v", err)
		}
		time.Sleep(2 * time.Millisecond)
	}
	stream.CloseSend()
	<-waits
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
