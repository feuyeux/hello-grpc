package org.feuyeux.grpc.client;

import static org.feuyeux.grpc.common.Connection.*;
import static org.feuyeux.grpc.common.HelloUtils.buildLinkRequests;
import static org.feuyeux.grpc.common.HelloUtils.getVersion;

import io.grpc.Channel;
import io.grpc.ClientInterceptor;
import io.grpc.ClientInterceptors;
import io.grpc.ManagedChannel;
import io.grpc.stub.StreamObserver;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import javax.net.ssl.SSLException;
import org.feuyeux.grpc.common.Connection;
import org.feuyeux.grpc.common.ErrorMapper;
import org.feuyeux.grpc.proto.LandingServiceGrpc;
import org.feuyeux.grpc.proto.TalkRequest;
import org.feuyeux.grpc.proto.TalkResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * gRPC client implementation demonstrating all four RPC patterns.
 *
 * <p>This client follows the standardized structure:
 *
 * <ol>
 *   <li>Configuration constants
 *   <li>Logger initialization
 *   <li>Connection setup
 *   <li>RPC method implementations (unary, server streaming, client streaming, bidirectional)
 *   <li>Helper functions
 *   <li>Main execution function
 *   <li>Cleanup and shutdown
 * </ol>
 */
public class ProtoClient {
  private static final Logger log = LoggerFactory.getLogger("ProtoClient");

  // Configuration constants
  private static final int RETRY_ATTEMPTS = 3;
  private static final long RETRY_DELAY_MS = 2000;
  private static final int ITERATION_COUNT = 3;
  private static final long REQUEST_DELAY_MS = 200;
  private static final long SEND_DELAY_MS = 2;
  private static final long REQUEST_TIMEOUT_SECONDS = 5;
  private static final int DEFAULT_BATCH_SIZE = 5;

  private ManagedChannel channel;
  private LandingServiceGrpc.LandingServiceBlockingStub blockingStub;
  private LandingServiceGrpc.LandingServiceStub asyncStub;

  public ProtoClient() throws SSLException {
    this.channel = Connection.getChannel();
    connect(this.channel);
  }

  public static void main(String[] args) {
    log.info("Starting gRPC client [version: {}]", getVersion());

    ProtoClient protoClient = null;
    boolean success = false;

    // Attempt to establish connection and run all patterns
    for (int attempt = 1; attempt <= RETRY_ATTEMPTS; attempt++) {
      log.info("Connection attempt {}/{}", attempt, RETRY_ATTEMPTS);

      try {
        protoClient = new ProtoClient();

        // Run all the gRPC patterns
        runGrpcCalls(protoClient, REQUEST_DELAY_MS, ITERATION_COUNT);
        success = true;
        break; // Success, no retry needed

      } catch (Exception e) {
        log.error("Connection attempt {} failed: {}", attempt, e.getMessage());
        if (attempt < RETRY_ATTEMPTS) {
          log.info("Retrying in {}ms...", RETRY_DELAY_MS);
          try {
            Thread.sleep(RETRY_DELAY_MS);
          } catch (InterruptedException ie) {
            log.info("Client shutting down, aborting retries");
            Thread.currentThread().interrupt();
            break;
          }
        } else {
          log.error("Maximum connection attempts reached, exiting");
        }
      }
    }

    // Cleanup
    if (protoClient != null) {
      try {
        protoClient.shutdown();
      } catch (InterruptedException e) {
        log.error("Error during shutdown", e);
        Thread.currentThread().interrupt();
      }
    }

    if (!success) {
      log.error("Failed to execute all gRPC calls successfully");
      System.exit(1);
    }

    log.info("Client execution completed successfully");
  }

  /**
   * Executes all four gRPC patterns multiple times.
   *
   * @param client The client instance to use
   * @param delayMs Delay between iterations in milliseconds
   * @param iterations Number of times to run all patterns
   * @throws Exception If any RPC call fails
   */
  private static void runGrpcCalls(ProtoClient client, long delayMs, int iterations)
      throws Exception {
    for (int iteration = 1; iteration <= iterations; iteration++) {
      log.info("====== Starting iteration {}/{} ======", iteration, iterations);

      // 1. Unary RPC
      log.info("----- Executing unary RPC -----");
      TalkRequest unaryRequest = TalkRequest.newBuilder().setMeta("JAVA").setData("0").build();
      TalkResponse response = client.executeUnaryCall(unaryRequest);
      logResponse(response);

      // 2. Server streaming RPC
      log.info("----- Executing server streaming RPC -----");
      TalkRequest serverStreamRequest =
          TalkRequest.newBuilder().setMeta("JAVA").setData("0,1,2").build();
      client.executeServerStreamingCall(serverStreamRequest);

      // 3. Client streaming RPC
      log.info("----- Executing client streaming RPC -----");
      TalkResponse clientStreamResponse = client.executeClientStreamingCall(buildLinkRequests());
      logResponse(clientStreamResponse);

      // 4. Bidirectional streaming RPC
      log.info("----- Executing bidirectional streaming RPC -----");
      client.executeBidirectionalStreamingCall(buildLinkRequests());

      // Wait before next iteration, unless it's the last one
      if (iteration < iterations) {
        log.info("Waiting {}ms before next iteration...", delayMs);
        Thread.sleep(delayMs);
      }
    }

    log.info("All gRPC calls completed successfully");
  }

  /**
   * Demonstrates the unary RPC pattern.
   *
   * @param request The request to send
   * @return The response from the server
   */
  public TalkResponse executeUnaryCall(TalkRequest request) {
    String requestId = "unary-" + System.nanoTime();
    log.info("Sending unary request: data={}, meta={}", request.getData(), request.getMeta());

    long startTime = System.currentTimeMillis();
    try {
      TalkResponse response = blockingStub.talk(request);
      long duration = System.currentTimeMillis() - startTime;
      log.info("Unary call successful in {}ms", duration);
      return response;
    } catch (Exception e) {
      Map<String, Object> context = new HashMap<>();
      context.put("requestId", requestId);
      ErrorMapper.handleRpcError(e, "Talk", context);
      throw e;
    }
  }

  /**
   * Demonstrates the server streaming RPC pattern.
   *
   * @param request The request to send
   * @throws Exception If the RPC call fails
   */
  public void executeServerStreamingCall(TalkRequest request) throws Exception {
    String requestId = "server-stream-" + System.nanoTime();
    log.info(
        "Starting server streaming with request: data={}, meta={}",
        request.getData(),
        request.getMeta());

    long startTime = System.currentTimeMillis();
    int responseCount = 0;

    try {
      Iterator<TalkResponse> responses = blockingStub.talkOneAnswerMore(request);

      while (responses.hasNext()) {
        TalkResponse response = responses.next();
        responseCount++;
        log.info("Received server streaming response #{}:", responseCount);
        logResponse(response);
      }

      long duration = System.currentTimeMillis() - startTime;
      log.info(
          "Server streaming completed: received {} responses in {}ms", responseCount, duration);

    } catch (Exception e) {
      Map<String, Object> context = new HashMap<>();
      context.put("requestId", requestId);
      ErrorMapper.handleRpcError(e, "TalkOneAnswerMore", context);
      throw e;
    }
  }

  /**
   * Demonstrates the client streaming RPC pattern.
   *
   * @param requests The list of requests to send
   * @return The response from the server
   * @throws InterruptedException If the operation is interrupted
   */
  public TalkResponse executeClientStreamingCall(LinkedList<TalkRequest> requests)
      throws InterruptedException {
    String requestId = "client-stream-" + System.nanoTime();
    log.info("Starting client streaming with {} requests", requests.size());

    long startTime = System.currentTimeMillis();
    final CountDownLatch finishLatch = new CountDownLatch(1);
    final TalkResponse[] responseHolder = new TalkResponse[1];
    final Exception[] errorHolder = new Exception[1];

    StreamObserver<TalkResponse> responseObserver =
        new StreamObserver<>() {
          @Override
          public void onNext(TalkResponse response) {
            responseHolder[0] = response;
          }

          @Override
          public void onError(Throwable t) {
            Map<String, Object> context = new HashMap<>();
            context.put("requestId", requestId);
            ErrorMapper.handleRpcError(t, "TalkMoreAnswerOne", context);
            errorHolder[0] = new Exception(t);
            finishLatch.countDown();
          }

          @Override
          public void onCompleted() {
            finishLatch.countDown();
          }
        };

    StreamObserver<TalkRequest> requestObserver = asyncStub.talkMoreAnswerOne(responseObserver);

    try {
      int requestCount = 0;
      for (TalkRequest request : requests) {
        requestCount++;
        log.info(
            "Sending client streaming request #{}: data={}, meta={}",
            requestCount,
            request.getData(),
            request.getMeta());
        requestObserver.onNext(request);
        TimeUnit.MILLISECONDS.sleep(SEND_DELAY_MS);
      }

      // Close the stream and wait for response
      requestObserver.onCompleted();

      if (!finishLatch.await(REQUEST_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
        throw new RuntimeException("Client streaming timed out");
      }

      if (errorHolder[0] != null) {
        throw errorHolder[0];
      }

      long duration = System.currentTimeMillis() - startTime;
      log.info("Client streaming completed: sent {} requests in {}ms", requestCount, duration);

      return responseHolder[0];

    } catch (InterruptedException e) {
      requestObserver.onError(e);
      throw e;
    } catch (Exception e) {
      requestObserver.onError(e);
      throw new RuntimeException(e);
    }
  }

  /**
   * Demonstrates the bidirectional streaming RPC pattern.
   *
   * @param requests The list of requests to send
   * @throws InterruptedException If the operation is interrupted
   */
  public void executeBidirectionalStreamingCall(List<TalkRequest> requests)
      throws InterruptedException {
    String requestId = "bidirectional-" + System.nanoTime();
    log.info("Starting bidirectional streaming with {} requests", requests.size());

    long startTime = System.currentTimeMillis();
    final CountDownLatch finishLatch = new CountDownLatch(1);
    final AtomicInteger responseCount = new AtomicInteger(0);
    final Exception[] errorHolder = new Exception[1];

    StreamObserver<TalkResponse> responseObserver =
        new StreamObserver<>() {
          @Override
          public void onNext(TalkResponse response) {
            int count = responseCount.incrementAndGet();
            log.info("Received bidirectional streaming response #{}:", count);
            logResponse(response);
          }

          @Override
          public void onError(Throwable t) {
            Map<String, Object> context = new HashMap<>();
            context.put("requestId", requestId);
            ErrorMapper.handleRpcError(t, "TalkBidirectional", context);
            errorHolder[0] = new Exception(t);
            finishLatch.countDown();
          }

          @Override
          public void onCompleted() {
            log.info("Bidirectional stream completed: received {} responses", responseCount.get());
            finishLatch.countDown();
          }
        };

    StreamObserver<TalkRequest> requestObserver = asyncStub.talkBidirectional(responseObserver);

    try {
      int requestCount = 0;
      for (TalkRequest request : requests) {
        requestCount++;
        log.info(
            "Sending bidirectional streaming request #{}: data={}, meta={}",
            requestCount,
            request.getData(),
            request.getMeta());
        requestObserver.onNext(request);
        TimeUnit.MILLISECONDS.sleep(SEND_DELAY_MS);
      }

      // Close sending side of stream
      log.info("Closing send side of bidirectional stream");
      requestObserver.onCompleted();

      // Wait for receiving side to complete
      if (!finishLatch.await(REQUEST_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
        throw new RuntimeException("Bidirectional streaming timed out");
      }

      if (errorHolder[0] != null) {
        throw errorHolder[0];
      }

      long duration = System.currentTimeMillis() - startTime;
      log.info("Bidirectional streaming completed in {}ms", duration);

    } catch (InterruptedException e) {
      requestObserver.onError(e);
      throw e;
    } catch (Exception e) {
      requestObserver.onError(e);
      throw new RuntimeException(e);
    }
  }

  /**
   * Logs the response in a standardized format.
   *
   * @param response The response to log
   */
  public static void logResponse(TalkResponse response) {
    if (response == null) {
      log.warn("Received nil response");
      return;
    }

    int resultsCount = response.getResultsCount();
    log.info("Response status: {}, results: {}", response.getStatus(), resultsCount);

    for (int i = 0; i < resultsCount; i++) {
      var result = response.getResults(i);
      Map<String, String> kv = result.getKvMap();

      String meta = kv.getOrDefault("meta", "");
      String id = kv.getOrDefault("id", "");
      String idx = kv.getOrDefault("idx", "");
      String data = kv.getOrDefault("data", "");

      log.info(
          "  Result #{}: id={}, type={}, meta={}, id={}, idx={}, data={}",
          i + 1,
          result.getId(),
          result.getType(),
          meta,
          id,
          idx,
          data);
    }
  }

  /**
   * Establishes connection to the gRPC server.
   *
   * @param channel The managed channel to use
   * @throws SSLException If SSL context setup fails
   */
  public void connect(ManagedChannel channel) throws SSLException {
    ClientInterceptor interceptor = new HeaderClientInterceptor();
    Channel interceptChannel = ClientInterceptors.intercept(channel, interceptor);
    blockingStub = LandingServiceGrpc.newBlockingStub(interceptChannel);
    asyncStub = LandingServiceGrpc.newStub(interceptChannel);
  }

  /**
   * Shuts down the client and releases resources.
   *
   * @throws InterruptedException If shutdown is interrupted
   */
  public void shutdown() throws InterruptedException {
    if (channel != null) {
      log.debug("Closing client connection");
      channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
    }
  }

  public ManagedChannel getChannel() {
    return channel;
  }
}
