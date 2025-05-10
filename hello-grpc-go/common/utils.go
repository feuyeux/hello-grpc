package common

import (
	"container/list"
	"fmt"
	"hello-grpc/common/pb"
	"math/rand"
	"strconv"
	"time"

	"google.golang.org/grpc"
)

var (
	helloList = []string{"Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"}
	// make(map[string]string)
	ansMap = map[string]string{
		"你好":      "非常感谢",
		"Hello":   "Thank you very much",
		"Bonjour": "Merci beaucoup",
		"Hola":    "Muchas Gracias",
		"こんにちは":   "どうも ありがとう ございます",
		"Ciao":    "Mille Grazie",
		"안녕하세요":   "대단히 감사합니다",
	}
)

func GetHelloList() []string {
	return helloList
}

func GetAnswerMap() map[string]string {
	return ansMap
}

func BuildLinkRequests() *list.List {
	requests := list.New()
	for i := 0; i < 3; i++ {
		requests.PushFront(&pb.TalkRequest{
			Data: RandomId(5), Meta: "GOLANG",
		})
	}
	return requests
}

func RandomId(max int) string {
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	n := r.Intn(max)
	return strconv.Itoa(n)
}

// GetVersion returns the gRPC version string
func GetVersion() string {
	return fmt.Sprintf("grpc.version=%s", grpc.Version)
}
