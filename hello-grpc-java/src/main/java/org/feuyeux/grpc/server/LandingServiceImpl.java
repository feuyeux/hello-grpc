package org.feuyeux.grpc.server;

import static org.feuyeux.grpc.common.HelloUtils.getAnswerMap;
import static org.feuyeux.grpc.common.HelloUtils.getHelloList;

import io.grpc.stub.StreamObserver;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.feuyeux.grpc.proto.LandingServiceGrpc;
import org.feuyeux.grpc.proto.ResultType;
import org.feuyeux.grpc.proto.TalkRequest;
import org.feuyeux.grpc.proto.TalkResponse;
import org.feuyeux.grpc.proto.TalkResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Implementation of the LandingService gRPC service.
 *
 * <p>This class demonstrates four gRPC communication patterns:
 *
 * <ol>
 *   <li>Unary RPC - Simple request/response model
 *   <li>Server Streaming RPC - Server sends multiple responses to a single client request
 *   <li>Client Streaming RPC - Client sends multiple requests and server responds with a single
 *       response
 *   <li>Bidirectional Streaming RPC - Both client and server send a sequence of messages
 * </ol>
 */
public class LandingServiceImpl extends LandingServiceGrpc.LandingServiceImplBase {
  private static final Logger logger = LoggerFactory.getLogger(LandingServiceImpl.class);
  private LandingServiceGrpc.LandingServiceBlockingStub blockingStub;
  private LandingServiceGrpc.LandingServiceStub asyncStub;

  /**
   * Sets the blocking stub for connecting to a backend gRPC service. Used for proxying requests to
   * another gRPC server in a chain.
   *
   * @param blockingStub The blocking stub for the backend service
   */
  public void setBlockingStub(LandingServiceGrpc.LandingServiceBlockingStub blockingStub) {
    this.blockingStub = blockingStub;
  }

  /**
   * Sets the async stub for connecting to a backend gRPC service. Used for proxying streaming
   * requests to another gRPC server in a chain.
   *
   * @param asyncStub The async stub for the backend service
   */
  public void setAsyncStub(LandingServiceGrpc.LandingServiceStub asyncStub) {
    this.asyncStub = asyncStub;
  }

  /**
   * Unary RPC implementation.
   *
   * <p>Handles a single request and returns a single response. If a backend stub is configured,
   * proxies the request to the next service.
   *
   * @param request The client request containing data and metadata
   * @param responseObserver The observer to send the response back to the client
   */
  @Override
  public void talk(TalkRequest request, StreamObserver<TalkResponse> responseObserver) {
    logger.info("Unary call - data: {}, meta: {}", request.getData(), request.getMeta());

    TalkResponse response;
    if (blockingStub == null) {
      // Process request locally
      response =
          TalkResponse.newBuilder()
              .setStatus(200)
              .addResults(createResult(request.getData()))
              .build();
    } else {
      // Forward request to backend service
      response = blockingStub.talk(request);
    }

    responseObserver.onNext(response);
    responseObserver.onCompleted();
  }

  /**
   * Server streaming RPC implementation.
   *
   * <p>Handles a single request and returns multiple responses through the stream. If backend stub
   * is configured, proxies the request to the next service.
   *
   * @param request The client request containing comma-separated data values
   * @param responseObserver The observer to send multiple responses back to the client
   */
  @Override
  public void talkOneAnswerMore(
      TalkRequest request, StreamObserver<TalkResponse> responseObserver) {
    logger.info("Server streaming call - data: {}, meta: {}", request.getData(), request.getMeta());

    if (blockingStub == null) {
      // Process request locally
      String[] dataItems = request.getData().split(",");
      for (String dataItem : dataItems) {
        TalkResponse response =
            TalkResponse.newBuilder().setStatus(200).addResults(createResult(dataItem)).build();
        responseObserver.onNext(response);
      }
    } else {
      // Forward request to backend service
      Iterator<TalkResponse> responseIterator = blockingStub.talkOneAnswerMore(request);
      responseIterator.forEachRemaining(responseObserver::onNext);
    }

    responseObserver.onCompleted();
  }

  /**
   * Client streaming RPC implementation.
   *
   * <p>Handles multiple requests from the client and returns a single response. If backend stub is
   * configured, proxies all requests to the next service.
   *
   * @param responseObserver The observer to send the final response back to the client
   * @return A StreamObserver to receive the client's stream of requests
   */
  @Override
  public StreamObserver<TalkRequest> talkMoreAnswerOne(
      StreamObserver<TalkResponse> responseObserver) {
    if (asyncStub == null) {
      // Process requests locally
      return new StreamObserver<>() {
        private final List<TalkResult> results = new ArrayList<>();

        @Override
        public void onNext(TalkRequest request) {
          logger.info(
              "Client streaming request - data: {}, meta: {}",
              request.getData(),
              request.getMeta());
          results.add(createResult(request.getData()));
        }

        @Override
        public void onError(Throwable t) {
          logger.error("Error in client streaming", t);
          responseObserver.onError(t);
        }

        @Override
        public void onCompleted() {
          // Send combined response with all results
          TalkResponse response =
              TalkResponse.newBuilder().setStatus(200).addAllResults(results).build();
          responseObserver.onNext(response);
          responseObserver.onCompleted();
        }
      };
    } else {
      // Forward requests to backend service
      StreamObserver<TalkResponse> backendResponseHandler =
          createResponseForwarder(responseObserver);
      StreamObserver<TalkRequest> requestObserver =
          asyncStub.talkMoreAnswerOne(backendResponseHandler);

      return new StreamObserver<>() {
        @Override
        public void onNext(TalkRequest request) {
          logger.info(
              "Client streaming request (forwarding) - data: {}, meta: {}",
              request.getData(),
              request.getMeta());
          requestObserver.onNext(request);
        }

        @Override
        public void onError(Throwable t) {
          logger.error("Error in client streaming", t);
          requestObserver.onError(t);
        }

        @Override
        public void onCompleted() {
          requestObserver.onCompleted();
        }
      };
    }
  }

  /**
   * Creates a response observer that forwards responses from a backend service to the client.
   *
   * @param responseObserver The original response observer from the client
   * @return A new response observer that forwards responses to the client
   */
  private StreamObserver<TalkResponse> createResponseForwarder(
      StreamObserver<TalkResponse> responseObserver) {
    return new StreamObserver<>() {
      @Override
      public void onNext(TalkResponse response) {
        responseObserver.onNext(response);
      }

      @Override
      public void onError(Throwable t) {
        logger.error("Error from backend service", t);
        responseObserver.onError(t);
      }

      @Override
      public void onCompleted() {
        responseObserver.onCompleted();
      }
    };
  }

  /**
   * Bidirectional streaming RPC implementation.
   *
   * <p>Handles multiple requests from the client and returns multiple responses. Each request
   * receives a corresponding response. If backend stub is configured, proxies all requests to the
   * next service.
   *
   * @param responseObserver The observer to send responses back to the client
   * @return A StreamObserver to receive the client's stream of requests
   */
  @Override
  public StreamObserver<TalkRequest> talkBidirectional(
      StreamObserver<TalkResponse> responseObserver) {
    if (asyncStub == null) {
      // Process requests locally
      return new StreamObserver<>() {
        @Override
        public void onNext(TalkRequest request) {
          logger.info(
              "Bidirectional streaming request - data: {}, meta: {}",
              request.getData(),
              request.getMeta());

          // Send a response for each request
          TalkResponse response =
              TalkResponse.newBuilder()
                  .setStatus(200)
                  .addResults(createResult(request.getData()))
                  .build();
          responseObserver.onNext(response);
        }

        @Override
        public void onError(Throwable t) {
          logger.error("Error in bidirectional streaming", t);
          responseObserver.onError(t);
        }

        @Override
        public void onCompleted() {
          responseObserver.onCompleted();
        }
      };
    } else {
      // Forward requests to backend service
      StreamObserver<TalkResponse> backendResponseHandler =
          createResponseForwarder(responseObserver);
      StreamObserver<TalkRequest> requestObserver =
          asyncStub.talkBidirectional(backendResponseHandler);

      return new StreamObserver<>() {
        @Override
        public void onNext(TalkRequest request) {
          logger.info(
              "Bidirectional streaming request (forwarding) - data: {}, meta: {}",
              request.getData(),
              request.getMeta());
          requestObserver.onNext(request);
        }

        @Override
        public void onError(Throwable t) {
          logger.error("Error in bidirectional streaming", t);
          requestObserver.onError(t);
        }

        @Override
        public void onCompleted() {
          requestObserver.onCompleted();
        }
      };
    }
  }

  /**
   * Creates a TalkResult object with the given data ID.
   *
   * @param id The request ID (typically a language index)
   * @return A TalkResult with timestamp, type and key-value data
   */
  private TalkResult createResult(String id) {
    // Parse the ID to an integer index
    int index;
    try {
      index = Integer.parseInt(id);
    } catch (NumberFormatException e) {
      index = 0;
    }

    // Get the greeting based on index
    String greeting = (index > 5) ? "你好" : getHelloList().get(index);
    String answer = getAnswerMap().get(greeting);

    // Create key-value data
    Map<String, String> kv = new HashMap<>();
    kv.put("id", UUID.randomUUID().toString());
    kv.put("idx", id);
    kv.put("data", greeting + "," + answer);
    kv.put("meta", "JAVA");

    // Build and return result
    return TalkResult.newBuilder()
        .setId(System.nanoTime())
        .setType(ResultType.OK)
        .putAllKv(kv)
        .build();
  }
}
