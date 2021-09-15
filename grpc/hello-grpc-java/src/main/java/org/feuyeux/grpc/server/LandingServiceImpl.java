package org.feuyeux.grpc.server;

import io.grpc.stub.StreamObserver;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.feuyeux.grpc.proto.LandingServiceGrpc;
import org.feuyeux.grpc.proto.ResultType;
import org.feuyeux.grpc.proto.TalkRequest;
import org.feuyeux.grpc.proto.TalkResponse;
import org.feuyeux.grpc.proto.TalkResult;

@Slf4j
public class LandingServiceImpl extends LandingServiceGrpc.LandingServiceImplBase {

  private final List<String> HELLO_LIST = Arrays.asList("Hello", "Bonjour", "Hola", "こんにちは", "Ciao",
      "안녕하세요");

  private LandingServiceGrpc.LandingServiceBlockingStub blockingStub;
  private LandingServiceGrpc.LandingServiceStub asyncStub;

  public void setBlockingStub(LandingServiceGrpc.LandingServiceBlockingStub blockingStub) {
    this.blockingStub = blockingStub;
  }

  public void setAsyncStub(LandingServiceGrpc.LandingServiceStub asyncStub) {
    this.asyncStub = asyncStub;
  }

  @Override
  public void talk(TalkRequest request, StreamObserver<TalkResponse> responseObserver) {
    log.info("TALK REQUEST: data={},meta={}", request.getData(), request.getMeta());
    TalkResponse response;
    if (blockingStub == null) {
      response = TalkResponse.newBuilder()
          .setStatus(200)
          .addResults(buildResult(request.getData())).build();
    } else {
      response = blockingStub.talk(request);
    }
    responseObserver.onNext(response);
    responseObserver.onCompleted();
  }

  @Override
  public void talkOneAnswerMore(TalkRequest request,
      StreamObserver<TalkResponse> responseObserver) {
    log.info("TalkOneAnswerMore REQUEST: data={},meta={}", request.getData(), request.getMeta());
    if (blockingStub == null) {
      List<TalkResponse> talkResponses = new ArrayList<>();
      String[] datas = request.getData().split(",");
      for (String data : datas) {
        TalkResponse response = TalkResponse.newBuilder()
            .setStatus(200)
            .addResults(buildResult(data)).build();
        talkResponses.add(response);
      }
      talkResponses.forEach(responseObserver::onNext);
    } else {
      Iterator<TalkResponse> talkResponses = blockingStub.talkOneAnswerMore(request);
      talkResponses.forEachRemaining(responseObserver::onNext);
    }
    responseObserver.onCompleted();
  }

  @Override
  public StreamObserver<TalkRequest> talkMoreAnswerOne(
      StreamObserver<TalkResponse> responseObserver) {
    if (asyncStub == null) {
      return new StreamObserver<>() {
        final List<TalkResult> talkResults = new ArrayList<>();

        @Override
        public void onNext(TalkRequest request) {
          log.info("TalkMoreAnswerOne REQUEST: data={},meta={}", request.getData(),
              request.getMeta());
          talkResults.add(buildResult(request.getData()));
        }

        @Override
        public void onError(Throwable t) {
          log.error("TalkMoreAnswerOne onError");
        }

        @Override
        public void onCompleted() {
          responseObserver.onNext(
              TalkResponse.newBuilder().setStatus(200).addAllResults(talkResults).build());
          responseObserver.onCompleted();
        }
      };
    } else {
      StreamObserver<TalkResponse> nextObserver = new StreamObserver<>() {
        @Override
        public void onNext(TalkResponse talkResponse) {
          responseObserver.onNext(talkResponse);
        }

        @Override
        public void onError(Throwable t) {
          log.error("", t);
        }

        @Override
        public void onCompleted() {
          responseObserver.onCompleted();
        }
      };
      return new StreamObserver<>() {
        final StreamObserver<TalkRequest> requestObserver = asyncStub.talkMoreAnswerOne(
            nextObserver);

        @Override
        public void onNext(TalkRequest request) {
          log.info("TalkMoreAnswerOne REQUEST: data={},meta={}", request.getData(),
              request.getMeta());
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

  @Override
  public StreamObserver<TalkRequest> talkBidirectional(
      StreamObserver<TalkResponse> responseObserver) {
    if (asyncStub == null) {
      return new StreamObserver<>() {
        @Override
        public void onNext(TalkRequest request) {
          log.info("TalkBidirectional REQUEST: data={},meta={}", request.getData(),
              request.getMeta());
          responseObserver.onNext(
              TalkResponse.newBuilder().setStatus(200).addResults(buildResult(request.getData()))
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
      StreamObserver<TalkResponse> nextObserver = new StreamObserver<TalkResponse>() {
        @Override
        public void onNext(TalkResponse talkResponse) {
          responseObserver.onNext(talkResponse);
        }

        @Override
        public void onError(Throwable t) {
          log.error("", t);
        }

        @Override
        public void onCompleted() {
          responseObserver.onCompleted();
        }
      };

      final StreamObserver<TalkRequest> requestObserver = asyncStub.talkBidirectional(nextObserver);

      return new StreamObserver<TalkRequest>() {
        @Override
        public void onNext(TalkRequest request) {
          log.info("TalkBidirectional REQUEST: data={},meta={}", request.getData(),
              request.getMeta());
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

  private TalkResult buildResult(String id) {
    int index;
    try {
      index = Integer.parseInt(id);
    } catch (NumberFormatException ignored) {
      index = 0;
    }
    String data;
    if (index > 5) {
      data = "你好";
    } else {
      data = HELLO_LIST.get(index);
    }
    Map<String, String> kv = new HashMap<>();
    kv.put("id", UUID.randomUUID().toString());
    kv.put("idx", id);
    kv.put("data", data);
    kv.put("meta", "JAVA");
    return TalkResult.newBuilder()
        .setId(System.nanoTime())
        .setType(ResultType.OK)
        .putAllKv(kv)
        .build();
  }
}
