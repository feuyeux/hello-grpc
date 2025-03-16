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
 * Implementation of the LandingService gRPC service. This class demonstrates four different types
 * of gRPC communication: 1. Unary RPC - Simple request/response model 2. Server Streaming RPC -
 * Server sends multiple responses to a single client request 3. Client Streaming RPC - Client sends
 * multiple requests and server responds with a single response 4. Bidirectional Streaming RPC -
 * Both client and server send a sequence of messages
 */
public class LandingServiceImpl extends LandingServiceGrpc.LandingServiceImplBase {
  private static final Logger log = LoggerFactory.getLogger("LandingServiceImpl");
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
   * Unary RPC implementation. Handles a single request and returns a single response. If a backend
   * stub is configured, proxies the request to the next service.
   *
   * @param request The client request containing data and metadata
   * @param responseObserver The observer to send the response back to the client
   */
  @Override
  public void talk(TalkRequest request, StreamObserver<TalkResponse> responseObserver) {
    log.info("TALK REQUEST: data={},meta={}", request.getData(), request.getMeta());
    TalkResponse response;
    if (blockingStub == null) {
      // No backend service, process request directly
      response =
          TalkResponse.newBuilder()
              .setStatus(200)
              .addResults(buildResult(request.getData()))
              .build();
    } else {
      // Proxy request to backend service
      response = blockingStub.talk(request);
    }
    responseObserver.onNext(response);
    responseObserver.onCompleted();
  }

  /**
   * Server streaming RPC implementation. Handles a single request and returns multiple responses
   * through the stream. If backend stub is configured, proxies the request to the next service.
   *
   * @param request The client request containing comma-separated data values
   * @param responseObserver The observer to send multiple responses back to the client
   */
  @Override
  public void talkOneAnswerMore(
      TalkRequest request, StreamObserver<TalkResponse> responseObserver) {
    log.info("TalkOneAnswerMore REQUEST: data={},meta={}", request.getData(), request.getMeta());
    if (blockingStub == null) {
      // No backend service, process request directly
      List<TalkResponse> talkResponses = new ArrayList<>();
      String[] datas = request.getData().split(",");
      for (String data : datas) {
        TalkResponse response =
            TalkResponse.newBuilder().setStatus(200).addResults(buildResult(data)).build();
        talkResponses.add(response);
      }
      // Send each response individually through the stream
      talkResponses.forEach(responseObserver::onNext);
    } else {
      // Proxy request to backend service and forward all responses
      Iterator<TalkResponse> talkResponses = blockingStub.talkOneAnswerMore(request);
      talkResponses.forEachRemaining(responseObserver::onNext);
    }
    responseObserver.onCompleted();
  }

  /**
   * Client streaming RPC implementation. Handles multiple requests from the client and returns a
   * single response. If backend stub is configured, proxies all requests to the next service.
   *
   * @param responseObserver The observer to send the final response back to the client
   * @return A StreamObserver to receive the client's stream of requests
   */
  @Override
  public StreamObserver<TalkRequest> talkMoreAnswerOne(
      StreamObserver<TalkResponse> responseObserver) {
    if (asyncStub == null) {
      // No backend service, process requests directly
      return new StreamObserver<>() {
        final List<TalkResult> talkResults = new ArrayList<>();

        @Override
        public void onNext(TalkRequest request) {
          log.info(
              "TalkMoreAnswerOne REQUEST: data={},meta={}", request.getData(), request.getMeta());
          talkResults.add(buildResult(request.getData()));
        }

        @Override
        public void onError(Throwable t) {
          log.error("TalkMoreAnswerOne onError");
        }

        @Override
        public void onCompleted() {
          // When client has sent all requests, combine results and send single response
          responseObserver.onNext(
              TalkResponse.newBuilder().setStatus(200).addAllResults(talkResults).build());
          responseObserver.onCompleted();
        }
      };
    } else {
      // Proxy all requests to backend service
      StreamObserver<TalkResponse> nextObserver = nextObserver(responseObserver);
      return new StreamObserver<>() {
        final StreamObserver<TalkRequest> requestObserver =
            asyncStub.talkMoreAnswerOne(nextObserver);

        @Override
        public void onNext(TalkRequest request) {
          log.info(
              "TalkMoreAnswerOne REQUEST: data={},meta={}", request.getData(), request.getMeta());
          requestObserver.onNext(request);
        }

        @Override
        public void onError(Throwable t) {
          log.error("TalkMoreAnswerOne onError");
        }

        @Override
        public void onCompleted() {
          requestObserver.onCompleted();
        }
      };
    }
  }

  /**
   * Helper method to create a response observer for proxying streaming responses from a backend
   * service to the client.
   *
   * @param responseObserver The original response observer from the client
   * @return A new response observer that forwards responses to the client
   */
  private StreamObserver<TalkResponse> nextObserver(StreamObserver<TalkResponse> responseObserver) {
    return new StreamObserver<>() {
      @Override
      public void onNext(TalkResponse talkResponse) {
        responseObserver.onNext(talkResponse);
      }

      @Override
      public void onError(Throwable t) {
        log.error("Error from backend service", t);
      }

      @Override
      public void onCompleted() {
        responseObserver.onCompleted();
      }
    };
  }

  /**
   * Bidirectional streaming RPC implementation. Handles multiple requests from the client and
   * returns multiple responses. Each request receives a corresponding response. If backend stub is
   * configured, proxies all requests to the next service.
   *
   * @param responseObserver The observer to send responses back to the client
   * @return A StreamObserver to receive the client's stream of requests
   */
  @Override
  public StreamObserver<TalkRequest> talkBidirectional(
      StreamObserver<TalkResponse> responseObserver) {
    if (asyncStub == null) {
      // No backend service, process requests directly
      return new StreamObserver<>() {
        @Override
        public void onNext(TalkRequest request) {
          log.info(
              "TalkBidirectional REQUEST: data={},meta={}", request.getData(), request.getMeta());
          // Send a response for each request received
          responseObserver.onNext(
              TalkResponse.newBuilder()
                  .setStatus(200)
                  .addResults(buildResult(request.getData()))
                  .build());
        }

        @Override
        public void onError(Throwable t) {
          log.error("TalkBidirectional onError");
        }

        @Override
        public void onCompleted() {
          responseObserver.onCompleted();
        }
      };
    } else {
      // Proxy all requests to backend service
      StreamObserver<TalkResponse> nextObserver = nextObserver(responseObserver);
      final StreamObserver<TalkRequest> requestObserver = asyncStub.talkBidirectional(nextObserver);
      return new StreamObserver<>() {
        @Override
        public void onNext(TalkRequest request) {
          log.info(
              "TalkBidirectional REQUEST: data={},meta={}", request.getData(), request.getMeta());
          requestObserver.onNext(request);
        }

        @Override
        public void onError(Throwable t) {
          log.error("TalkBidirectional onError", t);
        }

        @Override
        public void onCompleted() {
          requestObserver.onCompleted();
        }
      };
    }
  }

  /**
   * Builds a TalkResult object containing the response data.
   *
   * @param id The request ID (typically a language index)
   * @return A TalkResult with timestamp, type and key-value data
   */
  private TalkResult buildResult(String id) {
    int index;
    try {
      index = Integer.parseInt(id);
    } catch (NumberFormatException ignored) {
      index = 0;
    }
    String hello;
    if (index > 5) {
      hello = "你好";
    } else {
      hello = getHelloList().get(index);
    }
    Map<String, String> kv = new HashMap<>();
    kv.put("id", UUID.randomUUID().toString());
    kv.put("idx", id);
    kv.put("data", hello + "," + getAnswerMap().get(hello));
    kv.put("meta", "JAVA");
    return TalkResult.newBuilder()
        .setId(System.nanoTime())
        .setType(ResultType.OK)
        .putAllKv(kv)
        .build();
  }
}
