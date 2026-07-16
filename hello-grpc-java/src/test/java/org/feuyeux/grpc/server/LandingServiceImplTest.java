package org.feuyeux.grpc.server;

import static org.junit.jupiter.api.Assertions.*;

import io.grpc.ManagedChannel;
import io.grpc.Server;
import io.grpc.Status;
import io.grpc.StatusRuntimeException;
import io.grpc.inprocess.InProcessChannelBuilder;
import io.grpc.inprocess.InProcessServerBuilder;
import io.grpc.stub.StreamObserver;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.feuyeux.grpc.proto.LandingServiceGrpc;
import org.feuyeux.grpc.proto.TalkRequest;
import org.feuyeux.grpc.proto.TalkResponse;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** In-process integration tests covering the four gRPC call shapes of LandingServiceImpl. */
public class LandingServiceImplTest {

  private static Server server;
  private static ManagedChannel channel;
  private static LandingServiceGrpc.LandingServiceBlockingStub blockingStub;
  private static LandingServiceGrpc.LandingServiceStub asyncStub;

  @BeforeAll
  public static void setUp() throws Exception {
    String serverName = InProcessServerBuilder.generateName();
    server =
        InProcessServerBuilder.forName(serverName)
            .directExecutor()
            .addService(new LandingServiceImpl())
            .build()
            .start();
    channel = InProcessChannelBuilder.forName(serverName).directExecutor().build();
    blockingStub = LandingServiceGrpc.newBlockingStub(channel);
    asyncStub = LandingServiceGrpc.newStub(channel);
  }

  @AfterAll
  public static void tearDown() throws Exception {
    channel.shutdownNow().awaitTermination(5, TimeUnit.SECONDS);
    server.shutdownNow().awaitTermination(5, TimeUnit.SECONDS);
  }

  @Test
  @DisplayName("Unary RPC returns status 200 and one result with kv data")
  public void testTalk() {
    TalkRequest request = TalkRequest.newBuilder().setMeta("JAVA").setData("0").build();
    TalkResponse response = blockingStub.talk(request);

    assertEquals(200, response.getStatus());
    assertEquals(1, response.getResultsCount());
    var kv = response.getResults(0).getKvMap();
    assertEquals("0", kv.get("idx"));
    assertTrue(kv.containsKey("id"), "result should carry a generated id");
    assertNotNull(kv.get("data"));
  }

  @Test
  @DisplayName("Server streaming RPC returns one response per comma-separated item")
  public void testTalkOneAnswerMore() {
    TalkRequest request = TalkRequest.newBuilder().setMeta("JAVA").setData("0,1,2").build();
    Iterator<TalkResponse> iterator = blockingStub.talkOneAnswerMore(request);

    List<TalkResponse> responses = new ArrayList<>();
    iterator.forEachRemaining(responses::add);

    assertEquals(3, responses.size());
    for (int i = 0; i < 3; i++) {
      assertEquals(200, responses.get(i).getStatus());
      assertEquals(String.valueOf(i), responses.get(i).getResults(0).getKvMap().get("idx"));
    }
  }

  @Test
  @DisplayName("Client streaming RPC aggregates all requests into a single response")
  public void testTalkMoreAnswerOne() throws Exception {
    CountDownLatch latch = new CountDownLatch(1);
    List<TalkResponse> responses = new ArrayList<>();
    List<Throwable> errors = new ArrayList<>();

    StreamObserver<TalkRequest> requestObserver =
        asyncStub.talkMoreAnswerOne(
            new StreamObserver<>() {
              @Override
              public void onNext(TalkResponse response) {
                responses.add(response);
              }

              @Override
              public void onError(Throwable t) {
                errors.add(t);
                latch.countDown();
              }

              @Override
              public void onCompleted() {
                latch.countDown();
              }
            });

    requestObserver.onNext(TalkRequest.newBuilder().setMeta("JAVA").setData("0").build());
    requestObserver.onNext(TalkRequest.newBuilder().setMeta("JAVA").setData("1").build());
    requestObserver.onNext(TalkRequest.newBuilder().setMeta("JAVA").setData("2").build());
    requestObserver.onCompleted();

    assertTrue(latch.await(5, TimeUnit.SECONDS), "stream should complete");
    assertTrue(errors.isEmpty(), "no errors expected: " + errors);
    assertEquals(1, responses.size());
    assertEquals(200, responses.get(0).getStatus());
    assertEquals(3, responses.get(0).getResultsCount());
  }

  @Test
  @DisplayName("Bidirectional streaming RPC returns one response per request")
  public void testTalkBidirectional() throws Exception {
    CountDownLatch latch = new CountDownLatch(1);
    List<TalkResponse> responses = new ArrayList<>();
    List<Throwable> errors = new ArrayList<>();

    StreamObserver<TalkRequest> requestObserver =
        asyncStub.talkBidirectional(
            new StreamObserver<>() {
              @Override
              public void onNext(TalkResponse response) {
                responses.add(response);
              }

              @Override
              public void onError(Throwable t) {
                errors.add(t);
                latch.countDown();
              }

              @Override
              public void onCompleted() {
                latch.countDown();
              }
            });

    requestObserver.onNext(TalkRequest.newBuilder().setMeta("JAVA").setData("0").build());
    requestObserver.onNext(TalkRequest.newBuilder().setMeta("JAVA").setData("1").build());
    requestObserver.onCompleted();

    assertTrue(latch.await(5, TimeUnit.SECONDS), "stream should complete");
    assertTrue(errors.isEmpty(), "no errors expected: " + errors);
    assertEquals(2, responses.size());
    for (TalkResponse response : responses) {
      assertEquals(200, response.getStatus());
      assertEquals(1, response.getResultsCount());
    }
  }

  @Test
  @DisplayName("Unary RPC rejects invalid data")
  public void testTalkWithInvalidData() {
    for (String invalid : List.of("", "not-a-number", "-1", "99")) {
      TalkRequest request = TalkRequest.newBuilder().setMeta("JAVA").setData(invalid).build();
      StatusRuntimeException error =
          assertThrows(StatusRuntimeException.class, () -> blockingStub.talk(request));
      assertEquals(Status.Code.INVALID_ARGUMENT, error.getStatus().getCode());
    }
  }
}
