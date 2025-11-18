package main

import (
	"container/list"
	"context"
	"flag"
	"fmt"
	"hello-grpc/common"
	"hello-grpc/conn"
	"io"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"hello-grpc/common/pb"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc/metadata"
)

// Configuration constants
const (
	retryAttempts    = 3                      // Number of connection retry attempts
	retryDelay       = 2 * time.Second        // Delay between retries
	iterationCount   = 3                      // Number of times to run all gRPC patterns
	requestDelay     = 200 * time.Millisecond // Delay between iterations
	sendDelay        = 2 * time.Millisecond   // Delay between sending requests in streaming
	requestTimeout   = 5 * time.Second        // Timeout for individual requests
	defaultBatchSize = 5                      // Default number of requests in a batch
)

// Command-line flags
var (
	useTLS = flag.Bool("tls", false, "Enable TLS/SSL secure communication")
)

func init() {
	// Set up logging configuration
	log.SetFormatter(&log.TextFormatter{
		FullTimestamp:   true,
		TimestampFormat: "2006-01-02 15:04:05.000",
	})
}

func main() {
	// Parse command-line flags
	flag.Parse()

	// Set TLS environment variable if --tls flag is provided
	// This ensures backward compatibility with existing connection logic
	if *useTLS {
		os.Setenv("GRPC_HELLO_SECURE", "Y")
	}

	// Create root context with cancellation for the entire application
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Setup signal handling for graceful shutdown
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	// Create cancellation goroutine
	go func() {
		select {
		case <-shutdown:
			log.Info("Received shutdown signal, cancelling operations")
			cancel()
		case <-ctx.Done():
			// Context was cancelled elsewhere
			return
		}
	}()

	log.Infof("Starting gRPC client [version: %s]", common.GetVersion())

	// Attempt to establish connection and run all patterns
	var err error
	for attempt := 1; attempt <= retryAttempts; attempt++ {
		log.Infof("Connection attempt %d/%d", attempt, retryAttempts)

		// Connect to the gRPC server
		client, closeFunc, connErr := createClient(ctx)
		if connErr != nil {
			log.Errorf("Connection attempt %d failed: %v", attempt, connErr)
			if attempt < retryAttempts {
				log.Infof("Retrying in %v...", retryDelay)
				select {
				case <-time.After(retryDelay):
					continue
				case <-ctx.Done():
					log.Info("Client shutting down, aborting retries")
					return
				}
			}
			log.Error("Maximum connection attempts reached, exiting")
			os.Exit(1)
		}

		// Close the connection when we're done
		defer closeFunc()

		// Run all the gRPC patterns
		err = runGrpcCalls(ctx, client, requestDelay, iterationCount)
		if err == nil || ctx.Err() != nil {
			break // Success or deliberate cancellation, no retry needed
		}

		log.Errorf("Error running gRPC calls: %v", err)
		if attempt < retryAttempts {
			log.Infof("Will retry in %v...", retryDelay)
			select {
			case <-time.After(retryDelay):
				// Continue to next attempt
			case <-ctx.Done():
				log.Info("Client shutting down, aborting retries")
				return
			}
		}
	}

	if err != nil && ctx.Err() == nil {
		log.Error("Failed to execute all gRPC calls successfully")
		os.Exit(1)
	}

	if ctx.Err() != nil {
		log.Info("Client execution was cancelled")
	} else {
		log.Info("Client execution completed successfully")
	}
}

// createClient establishes a connection to the gRPC server and returns the client
func createClient(ctx context.Context) (pb.LandingServiceClient, func(), error) {
	cc, err := conn.ConnectWithContext(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create client connection: %w", err)
	}

	// Return the client and a cleanup function
	return pb.NewLandingServiceClient(cc), func() {
		log.Debug("Closing client connection")
		if err := cc.Close(); err != nil {
			log.Errorf("Error closing connection: %v", err)
		}
	}, nil
}

// runGrpcCalls executes all four gRPC patterns multiple times
func runGrpcCalls(ctx context.Context, client pb.LandingServiceClient, delay time.Duration, iterations int) error {
	for iteration := 1; iteration <= iterations; iteration++ {
		// Check if execution was cancelled
		if ctx.Err() != nil {
			return ctx.Err()
		}

		log.Infof("====== Starting iteration %d/%d ======", iteration, iterations)

		// 1. Unary RPC
		log.Infof("----- Executing unary RPC -----")
		if err := executeUnaryCall(ctx, client, &pb.TalkRequest{Data: "0", Meta: "GOLANG"}); err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			return fmt.Errorf("unary call failed: %w", err)
		}

		// 2. Server streaming RPC
		log.Infof("----- Executing server streaming RPC -----")
		if err := executeServerStreamingCall(ctx, client, &pb.TalkRequest{Data: "0,1,2", Meta: "GOLANG"}); err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			return fmt.Errorf("server streaming call failed: %w", err)
		}

		// 3. Client streaming RPC
		log.Infof("----- Executing client streaming RPC -----")
		response, err := executeClientStreamingCall(ctx, client, common.BuildLinkRequests())
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			return fmt.Errorf("client streaming call failed: %w", err)
		}
		common.LogResponse(response)

		// 4. Bidirectional streaming RPC
		log.Infof("----- Executing bidirectional streaming RPC -----")
		if err := executeBidirectionalStreamingCall(ctx, client, common.BuildLinkRequests()); err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			return fmt.Errorf("bidirectional streaming call failed: %w", err)
		}

		// Wait before next iteration, unless it's the last one
		if iteration < iterations {
			log.Infof("Waiting %v before next iteration...", delay)
			select {
			case <-time.After(delay):
				// Continue to next iteration
			case <-ctx.Done():
				log.Info("Client execution cancelled")
				return ctx.Err()
			}
		}
	}

	log.Info("All gRPC calls completed successfully")
	return nil
}

// executeUnaryCall demonstrates the unary RPC pattern
func executeUnaryCall(ctx context.Context, client pb.LandingServiceClient, request *pb.TalkRequest) error {
	// Create a timeout context
	callCtx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()

	// Add metadata to outgoing context
	requestID := fmt.Sprintf("unary-%d", time.Now().UnixNano())
	callCtx = addMetadata(callCtx, map[string]string{
		"request-id": requestID,
		"client":     "go-client",
	})

	log.Infof("Sending unary request: %+v", request)
	startTime := time.Now()

	response, err := client.Talk(callCtx, request)
	duration := time.Since(startTime)

	if err != nil {
		common.HandleRPCError(err, "Talk", map[string]interface{}{"requestID": requestID})
		return err
	}

	log.Infof("Unary call successful in %v", duration)
	common.LogResponse(response)
	return nil
}

// executeServerStreamingCall demonstrates the server streaming RPC pattern
func executeServerStreamingCall(ctx context.Context, client pb.LandingServiceClient, request *pb.TalkRequest) error {
	// Create a timeout context
	callCtx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()

	// Add metadata to outgoing context
	requestID := fmt.Sprintf("server-stream-%d", time.Now().UnixNano())
	callCtx = addMetadata(callCtx, map[string]string{
		"request-id": requestID,
		"client":     "go-client",
	})

	log.Infof("Starting server streaming with request: %+v", request)
	startTime := time.Now()

	stream, err := client.TalkOneAnswerMore(callCtx, request)
	if err != nil {
		common.HandleRPCError(err, "TalkOneAnswerMore", map[string]interface{}{"requestID": requestID})
		return err
	}

	// Process responses from the stream
	responseCount := 0
	for {
		// Check for context cancellation
		if ctx.Err() != nil {
			log.Info("Server streaming cancelled")
			return ctx.Err()
		}

		response, err := stream.Recv()
		if err == io.EOF {
			duration := time.Since(startTime)
			log.Infof("Server streaming completed: received %d responses in %v", responseCount, duration)
			break
		}
		if err != nil {
			common.HandleRPCError(err, "TalkOneAnswerMore.Recv", map[string]interface{}{"requestID": requestID})
			return err
		}

		responseCount++
		log.Infof("Received server streaming response #%d:", responseCount)
		common.LogResponse(response)
	}

	return nil
}

// executeClientStreamingCall demonstrates the client streaming RPC pattern
func executeClientStreamingCall(ctx context.Context, client pb.LandingServiceClient, requests *list.List) (*pb.TalkResponse, error) {
	// Create a timeout context
	callCtx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()

	// Add metadata to outgoing context
	requestID := fmt.Sprintf("client-stream-%d", time.Now().UnixNano())
	callCtx = addMetadata(callCtx, map[string]string{
		"request-id": requestID,
		"client":     "go-client",
	})

	log.Infof("Starting client streaming with %d requests", requests.Len())
	startTime := time.Now()

	stream, err := client.TalkMoreAnswerOne(callCtx)
	if err != nil {
		common.HandleRPCError(err, "TalkMoreAnswerOne", map[string]interface{}{"requestID": requestID})
		return nil, err
	}

	// Send each request in the stream
	requestCount := 0
	for e := requests.Front(); e != nil; e = e.Next() {
		// Check for context cancellation
		if ctx.Err() != nil {
			log.Info("Client streaming cancelled")
			return nil, ctx.Err()
		}

		request := e.Value.(*pb.TalkRequest)
		requestCount++

		log.Infof("Sending client streaming request #%d: %+v", requestCount, request)
		if err := stream.Send(request); err != nil {
			common.HandleRPCError(err, "TalkMoreAnswerOne.Send", map[string]interface{}{"requestID": requestID})
			return nil, err
		}

		// Small delay between sends to avoid overwhelming the server
		time.Sleep(sendDelay)
	}

	// Close the stream and get response
	response, err := stream.CloseAndRecv()
	duration := time.Since(startTime)

	if err != nil {
		common.HandleRPCError(err, "TalkMoreAnswerOne.CloseAndRecv", map[string]interface{}{"requestID": requestID})
		return nil, err
	}

	log.Infof("Client streaming completed: sent %d requests in %v", requestCount, duration)
	return response, nil
}

// executeBidirectionalStreamingCall demonstrates the bidirectional streaming RPC pattern
func executeBidirectionalStreamingCall(ctx context.Context, client pb.LandingServiceClient, requests *list.List) error {
	// Create a timeout context
	callCtx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()

	// Add metadata to outgoing context
	requestID := fmt.Sprintf("bidirectional-%d", time.Now().UnixNano())
	callCtx = addMetadata(callCtx, map[string]string{
		"request-id": requestID,
		"client":     "go-client",
	})

	log.Infof("Starting bidirectional streaming with %d requests", requests.Len())
	startTime := time.Now()

	stream, err := client.TalkBidirectional(callCtx)
	if err != nil {
		common.HandleRPCError(err, "TalkBidirectional", map[string]interface{}{"requestID": requestID})
		return err
	}

	// Use WaitGroup to coordinate sending and receiving
	var wg sync.WaitGroup
	wg.Add(1)

	// Error channel to communicate errors from goroutines
	errChan := make(chan error, 1)

	// Create context to coordinate cancellation between goroutines
	streamCtx, streamCancel := context.WithCancel(ctx)
	defer streamCancel()

	// Goroutine to handle responses from server
	go func() {
		defer wg.Done()

		responseCount := 0
		for {
			// Check for context cancellation
			if streamCtx.Err() != nil {
				return
			}

			response, err := stream.Recv()
			if err == io.EOF {
				// Server has completed sending
				log.Infof("Bidirectional stream completed: received %d responses", responseCount)
				return
			}
			if err != nil {
				// Don't log if cancelled - that's expected
				if streamCtx.Err() == nil {
					common.HandleRPCError(err, "TalkBidirectional.Recv", map[string]interface{}{"requestID": requestID})
					errChan <- err
				}
				return
			}

			responseCount++
			log.Infof("Received bidirectional streaming response #%d:", responseCount)
			common.LogResponse(response)
		}
	}()

	// Send all requests sequentially
	requestCount := 0
	for e := requests.Front(); e != nil; e = e.Next() {
		// Check for context cancellation
		select {
		case <-streamCtx.Done():
			log.Info("Bidirectional streaming cancelled")
			return streamCtx.Err()
		case err := <-errChan:
			return err
		default:
			// Continue processing
		}

		request := e.Value.(*pb.TalkRequest)
		requestCount++

		log.Infof("Sending bidirectional streaming request #%d: %+v", requestCount, request)
		if err := stream.Send(request); err != nil {
			// Cancel the receive goroutine
			streamCancel()
			common.HandleRPCError(err, "TalkBidirectional.Send", map[string]interface{}{"requestID": requestID})
			return err
		}

		// Add delay between sends
		time.Sleep(sendDelay)
	}

	// Close sending side of stream
	log.Info("Closing send side of bidirectional stream")
	if err := stream.CloseSend(); err != nil {
		common.HandleRPCError(err, "TalkBidirectional.CloseSend", map[string]interface{}{"requestID": requestID})
		return err
	}

	// Wait for receiving side to complete or for an error
	select {
	case err := <-errChan:
		return err
	case <-streamCtx.Done():
		return streamCtx.Err()
	case <-callCtx.Done():
		if callCtx.Err() == context.DeadlineExceeded {
			return fmt.Errorf("bidirectional streaming timed out")
		}
		return callCtx.Err()
	default:
		// Wait for completion
		wg.Wait()
		duration := time.Since(startTime)
		log.Infof("Bidirectional streaming completed in %v", duration)
		return nil
	}
}

// addMetadata adds key-value pairs to the outgoing context as metadata
func addMetadata(ctx context.Context, md map[string]string) context.Context {
	var pairs []string
	for k, v := range md {
		pairs = append(pairs, k, v)
	}
	return metadata.AppendToOutgoingContext(ctx, pairs...)
}
