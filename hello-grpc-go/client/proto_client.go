package main

import (
	"container/list"
	"hello-grpc/common"
	"hello-grpc/conn"
	"io"
	"sync"
	"time"

	"hello-grpc/common/pb"

	log "github.com/sirupsen/logrus"
	"golang.org/x/net/context"
	"google.golang.org/grpc/metadata"
)

const retries = 1
const loops = 3

func main() {
	for retry := 1; retry <= retries; retry++ {
		err := startTalking(*conn.Connect(), 200*time.Millisecond)
		if err != nil {
			log.Infof("retry %d", retry)
		}
	}
}

func startTalking(c pb.LandingServiceClient, tt time.Duration) error {
	for round := 1; round <= loops; round++ {
		log.Infof("round %d", round)
		//
		log.Infof("Unary RPC")
		err := talk(c, &pb.TalkRequest{Data: "0", Meta: "GOLANG"})
		if err != nil {
			return err
		}
		//
		log.Infof("Server streaming RPC")
		err = talkOneAnswerMore(c, &pb.TalkRequest{Data: "0,1,2", Meta: "GOLANG"})
		if err != nil {
			return err
		}
		//
		log.Infof("Client streaming RPC")

		r, err := talkMoreAnswerOne(c, common.BuildLinkRequests())
		if err != nil {
			return err
		}
		printResponse(r)

		//
		log.Infof("Bidirectional streaming RPC")
		err = talkBidirectional(c, common.BuildLinkRequests())
		if err != nil {
			return err
		}
		//
		time.Sleep(tt)
	}
	return nil
}

func talk(client pb.LandingServiceClient, request *pb.TalkRequest) error {
	ctx, cancelFunc := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancelFunc()
	ctx = metadata.AppendToOutgoingContext(ctx, "k1", "v1", "k2", "v2")

	r, err := client.Talk(ctx, request)
	if err != nil {
		log.Errorf("fail to talk: %v", err)
		return err
	}
	log.Infof("Request=%+v", request)
	printResponse(r)
	return nil
}

func talkOneAnswerMore(client pb.LandingServiceClient, request *pb.TalkRequest) error {
	ctx := metadata.AppendToOutgoingContext(context.Background(), "k1", "v1", "k2", "v2")
	stream, err := client.TalkOneAnswerMore(ctx, request)
	if err != nil {
		log.Errorf("%v.TalkOneAnswerMore(_) = _, %v", client, err)
		return err
	}
	backFirst := true
	for {
		r, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Errorf("%v.TalkOneAnswerMore(_) = _, %v", client, err)
			return err
		}
		if backFirst {
			log.Infof("Request=%+v", request)
			backFirst = false
		}
		printResponse(r)
	}
	return nil
}

func talkMoreAnswerOne(client pb.LandingServiceClient, requests *list.List) (*pb.TalkResponse, error) {
	ctx := metadata.AppendToOutgoingContext(context.Background(), "k1", "v1", "k2", "v2")
	stream, err := client.TalkMoreAnswerOne(ctx)
	if err != nil {
		log.Errorf("%v.TalkMoreAnswerOne(_) = _, %v", client, err)
		return nil, err
	}
	//
	var wg sync.WaitGroup
	l := requests.Len()
	wg.Add(l)
	i := 0
	for e := requests.Front(); e != nil; e = e.Next() {
		request := e.Value.(*pb.TalkRequest)
		go func(i int) {
			defer wg.Done()
			log.Infof("Request[%d]=%+v", i, request)
			if err := stream.Send(request); err != nil {
				log.Errorf("%v.Send(%v) = %v", stream, request, err)
			}
		}(i)
		i++
	}
	wg.Wait()
	//
	return stream.CloseAndRecv()
}

func talkBidirectional(client pb.LandingServiceClient, requests *list.List) error {
	ctx := metadata.AppendToOutgoingContext(context.Background(), "k1", "v1", "k2", "v2")
	stream, err := client.TalkBidirectional(ctx)
	if err != nil {
		log.Errorf("%v.TalkBidirectional(_) = _, %v", client, err)
		return err
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
				log.Errorf("Failed to receive a note : %v", err)
			}
			printResponse(r)
		}
	}()
	//
	for e := requests.Front(); e != nil; e = e.Next() {
		request := e.Value.(*pb.TalkRequest)
		log.Infof("Request=%+v", request)
		if err := stream.Send(request); err != nil {
			log.Errorf("Failed to send : %v", err)
		}
		time.Sleep(2 * time.Millisecond)
	}
	err = stream.CloseSend()
	if err != nil {
		return err
	}
	<-waits
	return nil
}

func printResponse(response *pb.TalkResponse) {
	if response != nil {
		for _, result := range response.Results {
			kv := result.Kv
			log.Infof("[%d] %d [%s %+v %s,%s:%s]",
				response.Status, result.Id, kv["meta"], result.Type, kv["id"], kv["idx"], kv["data"])
		}
	}
}
