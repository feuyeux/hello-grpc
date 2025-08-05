package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	pb "hello-grpc/hello-grpc-gateway/common/pb"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type Gateway struct {
	client pb.LandingServiceClient
}

type TalkRequestJSON struct {
	Data string `json:"data"`
	Meta string `json:"meta"`
}

type TalkResponseJSON struct {
	Status  int32                    `json:"status"`
	Results []map[string]interface{} `json:"results"`
}

func main() {
	log.Println("=== Hello gRPC Web Gateway Starting ===")

	// 连接到gRPC服务器
	log.Println("Connecting to gRPC server at localhost:9996...")
	conn, err := grpc.Dial("localhost:9996", grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("❌ Failed to connect to gRPC server: %v", err)
	}
	defer conn.Close()
	log.Println("✅ Successfully connected to gRPC server")

	gateway := &Gateway{
		client: pb.NewLandingServiceClient(conn),
	}

	// 设置CORS中间件
	mux := http.NewServeMux()

	log.Println("Setting up API endpoints:")
	mux.HandleFunc("/api/talk", loggingMiddleware("Talk", gateway.handleTalk))
	mux.HandleFunc("/api/talkOneAnswerMore", loggingMiddleware("TalkOneAnswerMore", gateway.handleTalkOneAnswerMore))
	mux.HandleFunc("/api/talkMoreAnswerOne", loggingMiddleware("TalkMoreAnswerOne", gateway.handleTalkMoreAnswerOne))
	mux.HandleFunc("/api/talkBidirectional", loggingMiddleware("TalkBidirectional", gateway.handleTalkBidirectional))

	log.Println("  - /api/talk")
	log.Println("  - /api/talkOneAnswerMore")
	log.Println("  - /api/talkMoreAnswerOne")
	log.Println("  - /api/talkBidirectional")

	// 包装CORS中间件
	handler := corsMiddleware(mux)

	log.Println("🚀 Hello gRPC Web Gateway started on :9997")
	log.Println("🌐 CORS enabled for all origins")
	log.Println("🔗 Gateway: localhost:9997 → gRPC Server: localhost:9996")
	log.Println("📡 Ready to handle requests...")
	log.Fatal(http.ListenAndServe(":9997", handler))
}

func loggingMiddleware(apiName string, next http.HandlerFunc) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		log.Printf("📨 [%s] %s %s - Started", apiName, r.Method, r.URL.Path)

		// 创建一个ResponseWriter包装器来捕获状态码
		wrapper := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(wrapper, r)

		duration := time.Since(start)
		statusIcon := "✅"
		if wrapper.statusCode >= 400 {
			statusIcon = "❌"
		}
		log.Printf("%s [%s] %s %s - %d - %v", statusIcon, apiName, r.Method, r.URL.Path, wrapper.statusCode, duration)
	})
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			log.Printf("🔄 CORS preflight request from %s", r.Header.Get("Origin"))
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func (g *Gateway) handleTalk(w http.ResponseWriter, r *http.Request) {
	var req TalkRequestJSON
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("❌ Talk: Invalid JSON request: %v", err)
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	log.Printf("🔄 Talk: Processing request - Data: %s, Meta: %s", req.Data, req.Meta)

	grpcReq := &pb.TalkRequest{
		Data: req.Data,
		Meta: req.Meta,
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	resp, err := g.client.Talk(ctx, grpcReq)
	if err != nil {
		log.Printf("❌ Talk: gRPC call failed: %v", err)
		http.Error(w, fmt.Sprintf("gRPC error: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("✅ Talk: Received response with %d results", len(resp.Results))

	// 转换响应
	results := make([]map[string]interface{}, len(resp.Results))
	for i, result := range resp.Results {
		results[i] = map[string]interface{}{
			"id":   result.Id,
			"type": result.Type.String(),
			"kv":   result.Kv,
		}
	}

	jsonResp := TalkResponseJSON{
		Status:  resp.Status,
		Results: results,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(jsonResp)
}

func (g *Gateway) handleTalkOneAnswerMore(w http.ResponseWriter, r *http.Request) {
	var req TalkRequestJSON
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("❌ TalkOneAnswerMore: Invalid JSON request: %v", err)
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	log.Printf("🔄 TalkOneAnswerMore: Processing streaming request - Data: %s, Meta: %s", req.Data, req.Meta)

	grpcReq := &pb.TalkRequest{
		Data: req.Data,
		Meta: req.Meta,
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	stream, err := g.client.TalkOneAnswerMore(ctx, grpcReq)
	if err != nil {
		log.Printf("❌ TalkOneAnswerMore: gRPC stream failed: %v", err)
		http.Error(w, fmt.Sprintf("gRPC error: %v", err), http.StatusInternalServerError)
		return
	}

	var responses []TalkResponseJSON
	streamCount := 0
	for {
		resp, err := stream.Recv()
		if err == io.EOF {
			log.Printf("✅ TalkOneAnswerMore: Stream completed with %d responses", streamCount)
			break
		}
		if err != nil {
			log.Printf("❌ TalkOneAnswerMore: Stream error: %v", err)
			http.Error(w, fmt.Sprintf("Stream error: %v", err), http.StatusInternalServerError)
			return
		}

		streamCount++
		log.Printf("📨 TalkOneAnswerMore: Received stream response %d", streamCount)

		results := make([]map[string]interface{}, len(resp.Results))
		for i, result := range resp.Results {
			results[i] = map[string]interface{}{
				"id":   result.Id,
				"type": result.Type.String(),
				"kv":   result.Kv,
			}
		}

		responses = append(responses, TalkResponseJSON{
			Status:  resp.Status,
			Results: results,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"results": responses,
	})
}

func (g *Gateway) handleTalkMoreAnswerOne(w http.ResponseWriter, r *http.Request) {
	var reqData struct {
		Requests []TalkRequestJSON `json:"requests"`
	}
	if err := json.NewDecoder(r.Body).Decode(&reqData); err != nil {
		log.Printf("❌ TalkMoreAnswerOne: Invalid JSON request: %v", err)
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	log.Printf("🔄 TalkMoreAnswerOne: Processing %d client streaming requests", len(reqData.Requests))

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	stream, err := g.client.TalkMoreAnswerOne(ctx)
	if err != nil {
		log.Printf("❌ TalkMoreAnswerOne: gRPC stream failed: %v", err)
		http.Error(w, fmt.Sprintf("gRPC error: %v", err), http.StatusInternalServerError)
		return
	}

	// 发送请求
	log.Printf("📤 TalkMoreAnswerOne: Sending %d requests to gRPC server", len(reqData.Requests))
	for i, req := range reqData.Requests {
		grpcReq := &pb.TalkRequest{
			Data: req.Data,
			Meta: req.Meta,
		}
		if err := stream.Send(grpcReq); err != nil {
			log.Printf("❌ TalkMoreAnswerOne: Send error at request %d: %v", i+1, err)
			http.Error(w, fmt.Sprintf("Send error: %v", err), http.StatusInternalServerError)
			return
		}
		log.Printf("📨 TalkMoreAnswerOne: Sent request %d/%d", i+1, len(reqData.Requests))
	}

	// 关闭并接收响应
	log.Printf("📥 TalkMoreAnswerOne: Closing stream and waiting for response")
	resp, err := stream.CloseAndRecv()
	if err != nil {
		log.Printf("❌ TalkMoreAnswerOne: CloseAndRecv error: %v", err)
		http.Error(w, fmt.Sprintf("Receive error: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("✅ TalkMoreAnswerOne: Received response with status %d", resp.Status)

	results := make([]map[string]interface{}, len(resp.Results))
	for i, result := range resp.Results {
		results[i] = map[string]interface{}{
			"id":   result.Id,
			"type": result.Type.String(),
			"kv":   result.Kv,
		}
	}

	respJSON := TalkResponseJSON{
		Status:  resp.Status,
		Results: results,
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(respJSON); err != nil {
		log.Printf("❌ TalkMoreAnswerOne: JSON encoding failed: %v", err)
		http.Error(w, "JSON encoding error", http.StatusInternalServerError)
		return
	}
	log.Printf("🎉 TalkMoreAnswerOne: Response sent successfully")
}

func (g *Gateway) handleTalkBidirectional(w http.ResponseWriter, r *http.Request) {
	var reqData struct {
		Requests []TalkRequestJSON `json:"requests"`
	}
	if err := json.NewDecoder(r.Body).Decode(&reqData); err != nil {
		log.Printf("❌ TalkBidirectional: Invalid JSON request: %v", err)
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	log.Printf("🔄 TalkBidirectional: Processing %d bidirectional streaming requests", len(reqData.Requests))

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	stream, err := g.client.TalkBidirectional(ctx)
	if err != nil {
		log.Printf("❌ TalkBidirectional: gRPC stream failed: %v", err)
		http.Error(w, fmt.Sprintf("gRPC error: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("📤 TalkBidirectional: Sending %d requests to gRPC server", len(reqData.Requests))
	// 发送请求
	for i, req := range reqData.Requests {
		grpcReq := &pb.TalkRequest{
			Data: req.Data,
			Meta: req.Meta,
		}
		if err := stream.Send(grpcReq); err != nil {
			log.Printf("❌ TalkBidirectional: Send error at request %d: %v", i+1, err)
			http.Error(w, fmt.Sprintf("Send error: %v", err), http.StatusInternalServerError)
			return
		}
		log.Printf("📨 TalkBidirectional: Sent request %d/%d", i+1, len(reqData.Requests))
	}

	// 关闭发送方向
	if err := stream.CloseSend(); err != nil {
		log.Printf("❌ TalkBidirectional: CloseSend error: %v", err)
		http.Error(w, fmt.Sprintf("CloseSend error: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("📥 TalkBidirectional: Receiving responses from gRPC server")
	var responses []TalkResponseJSON
	for {
		resp, err := stream.Recv()
		if err == io.EOF {
			log.Printf("📄 TalkBidirectional: Finished receiving (EOF)")
			break
		}
		if err != nil {
			log.Printf("❌ TalkBidirectional: Receive error: %v", err)
			http.Error(w, fmt.Sprintf("Receive error: %v", err), http.StatusInternalServerError)
			return
		}
		results := make([]map[string]interface{}, len(resp.Results))
		for i, result := range resp.Results {
			results[i] = map[string]interface{}{
				"id":   result.Id,
				"type": result.Type.String(),
				"kv":   result.Kv,
			}
		}

		responses = append(responses, TalkResponseJSON{
			Status:  resp.Status,
			Results: results,
		})
		log.Printf("📩 TalkBidirectional: Received response %d with status %d", len(responses), resp.Status)
	}

	log.Printf("✅ TalkBidirectional: Received total %d responses", len(responses))

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]interface{}{
		"responses": responses,
	}); err != nil {
		log.Printf("❌ TalkBidirectional: JSON encoding failed: %v", err)
		http.Error(w, "JSON encoding error", http.StatusInternalServerError)
		return
	}
	log.Printf("🎉 TalkBidirectional: Response sent successfully")
}
