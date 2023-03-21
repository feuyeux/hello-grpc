package org.feuyeux.grpc.client;

import static org.feuyeux.grpc.common.Connection.backEnd;
import static org.feuyeux.grpc.common.Connection.backPort;
import static org.feuyeux.grpc.common.Connection.currentPort;
import static org.feuyeux.grpc.common.Connection.secure;
import static org.feuyeux.grpc.common.Connection.server;
import static org.feuyeux.grpc.common.HelloUtils.buildLinkRequests;

import io.grpc.Channel;
import io.grpc.ClientInterceptor;
import io.grpc.ClientInterceptors;
import io.grpc.ManagedChannel;
import io.grpc.stub.StreamObserver;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import javax.net.ssl.SSLException;
import lombok.extern.slf4j.Slf4j;
import org.feuyeux.grpc.common.Connection;
import org.feuyeux.grpc.proto.LandingServiceGrpc;
import org.feuyeux.grpc.proto.TalkRequest;
import org.feuyeux.grpc.proto.TalkResponse;

@Slf4j
public class ProtoClient {

  private final ManagedChannel channel;
  private final LandingServiceGrpc.LandingServiceBlockingStub blockingStub;
  private final LandingServiceGrpc.LandingServiceStub asyncStub;

  public ProtoClient() throws SSLException {
    channel = Connection.getChannel();
    ClientInterceptor interceptor = new HeaderClientInterceptor();
    Channel interceptChannel = ClientInterceptors.intercept(channel, interceptor);
    blockingStub = LandingServiceGrpc.newBlockingStub(interceptChannel);
    asyncStub = LandingServiceGrpc.newStub(interceptChannel);
  }

  public static void main(String[] args) {
    log.info("GRPC_SERVER:{}", server);
    log.info("GRPC_SERVER_PORT:{}", currentPort);
    log.info("GRPC_HELLO_BACKEND:{}", backEnd);
    log.info("GRPC_HELLO_BACKEND_PORT:{}", backPort);
    log.info("GRPC_HELLO_SECURE:{}", secure);
    log.info("host:{}", System.getenv("host.docker.internal"));

    ProtoClient protoClient = null;
    try {
      protoClient = new ProtoClient();
      log.info("Unary RPC");
      TalkRequest talkRequest = TalkRequest.newBuilder()
          .setMeta("JAVA")
          .setData("0")
          .build();
      log.info("Request data:{},meta:{}", talkRequest.getData(), talkRequest.getMeta());
      TalkResponse response = protoClient.talk(talkRequest);
      printResponse(response);

      log.info("Server streaming RPC");
      talkRequest = TalkRequest.newBuilder()
          .setMeta("JAVA")
          .setData("0,1,2")
          .build();
      log.info("Request data:{},meta:{}", talkRequest.getData(), talkRequest.getMeta());
      List<TalkResponse> talkResponses = protoClient.talkOneAnswerMore(talkRequest);
      talkResponses.forEach(ProtoClient::printResponse);

      log.info("Client streaming RPC");
      protoClient.talkMoreAnswerOne(buildLinkRequests());

      log.info("Bidirectional streaming RPC");
      protoClient.talkBidirectional(buildLinkRequests());
    } catch (Exception e) {
      log.error("", e);
    } finally {
      if (protoClient != null) {
        try {
          protoClient.shutdown();
        } catch (InterruptedException e) {
          log.error("", e);
        }
      }
    }
  }



  private static void printResponse(TalkResponse response) {
    response.getResultsList().forEach(result -> {
          Map<String, String> kv = result.getKvMap();
          log.info("{} {} [{} {} {},{}:{}]", response.getStatus(), result.getId(),
              kv.get("meta"), result.getType(), kv.get("id"), kv.get("idx"), kv.get("data"));
        }
    );
  }

  public void shutdown() throws InterruptedException {
    channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
  }

  public TalkResponse talk(TalkRequest talkRequest) {
    return blockingStub.talk(talkRequest);
  }

  public List<TalkResponse> talkOneAnswerMore(TalkRequest request) {
    List<TalkResponse> talkResponseList = new ArrayList<>();
    Iterator<TalkResponse> talkResponses = blockingStub.talkOneAnswerMore(request);
    talkResponses.forEachRemaining(talkResponseList::add);
    return talkResponseList;
  }

  public void talkMoreAnswerOne(LinkedList<TalkRequest> requests) throws InterruptedException {
    final CountDownLatch finishLatch = new CountDownLatch(1);
    final StreamObserver<TalkRequest> requestObserver = asyncStub.talkMoreAnswerOne(
        getResponseObserver(finishLatch));
    try {
      requests.forEach(request -> {
        if (finishLatch.getCount() > 0) {
          log.info("Request data:{},meta:{}", request.getData(), request.getMeta());
          requestObserver.onNext(request);
          try {
            TimeUnit.MICROSECONDS.sleep(5);
          } catch (InterruptedException ignored) {
          }
        }
      });
    } catch (Exception e) {
      requestObserver.onError(e);
      throw e;
    }
    // Mark the end of requests
    requestObserver.onCompleted();

    // Receiving happens asynchronously
    if (!finishLatch.await(1, TimeUnit.MINUTES)) {
      log.warn("can not finish within 1 minutes");
    }
  }

  public void talkBidirectional(List<TalkRequest> requests) throws InterruptedException {
    final CountDownLatch finishLatch = new CountDownLatch(1);
    final StreamObserver<TalkRequest> requestObserver = asyncStub.talkBidirectional(
        getResponseObserver(finishLatch));
    try {
      requests.forEach(request -> {
        if (finishLatch.getCount() > 0) {
          log.info("Request data:{},meta:{}", request.getData(), request.getMeta());
          requestObserver.onNext(request);
          try {
            TimeUnit.SECONDS.sleep(1);
          } catch (InterruptedException ignored) {
          }
        }
      });
    } catch (Exception e) {
      requestObserver.onError(e);
      throw e;
    }
    // Mark the end of requests
    requestObserver.onCompleted();

    // Receiving happens asynchronously
    if (!finishLatch.await(1, TimeUnit.MINUTES)) {
      log.warn("can not finish within 1 minutes");
    }
  }

  private StreamObserver<TalkResponse> getResponseObserver(CountDownLatch finishLatch) {
    return new StreamObserver<>() {
      @Override
      public void onNext(TalkResponse talkResponse) {
        printResponse(talkResponse);
      }

      @Override
      public void onError(Throwable t) {
        log.error("", t);
        finishLatch.countDown();
      }

      @Override
      public void onCompleted() {
        finishLatch.countDown();
      }
    };
  }
}
