package org.feuyeux.grpc.client;

import static org.feuyeux.grpc.client.ProtoClient.printResponse;
import static org.feuyeux.grpc.common.Connection.*;
import static org.feuyeux.grpc.common.HelloUtils.buildLinkRequests;

import io.grpc.*;
import java.util.List;
import java.util.concurrent.TimeUnit;
import javax.net.ssl.SSLException;
import org.feuyeux.grpc.common.Connection;
import org.feuyeux.grpc.proto.TalkRequest;
import org.feuyeux.grpc.proto.TalkResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ProtoClientWithReconnect {
  private static final Logger log = LoggerFactory.getLogger("ProtoClientWithReconnect");
  private final int maxReconnectBackoffMillis;
  private final int initialReconnectBackoffMillis;
  private final double backoffMultiplier;
  private final int maxReconnectAttempts;
  private volatile int reconnectAttempts;
  private ProtoClient protoClient;

  public ProtoClientWithReconnect(ProtoClient protoClient) throws SSLException {
    this.protoClient = protoClient;
    //  最大重连退避时间（毫秒）
    maxReconnectBackoffMillis = 30000;
    // 初始重连退避时间（毫秒）
    initialReconnectBackoffMillis = 1000;
    // 退避乘数
    backoffMultiplier = 2.0;
    // 最大重连尝试次数
    maxReconnectAttempts = 5;
  }

  public static void main(String[] args) throws Exception {
    ProtoClientWithReconnect protoClient = new ProtoClientWithReconnect(new ProtoClient());
    protoClient.start();
  }

  public void start() {
    try {
      talking();
    } catch (Exception e) {
      log.error("", e);
    } finally {
      if (protoClient != null) {
        try {
          protoClient.shutdown();
        } catch (Exception e) {
          log.error("", e);
        }
      }
    }
  }

  private ManagedChannel getChannel() {
    return this.protoClient.getChannel();
  }

  private void talking() {
    try {
      do {
        log.info("Unary RPC");
        TalkRequest talkRequest = TalkRequest.newBuilder().setMeta("JAVA").setData("0").build();
        log.info("Request data:{},meta:{}", talkRequest.getData(), talkRequest.getMeta());
        TalkResponse response = protoClient.talk(talkRequest);
        printResponse(response);

        log.info("Server streaming RPC");
        talkRequest = TalkRequest.newBuilder().setMeta("JAVA").setData("0,1,2").build();
        log.info("Request data:{},meta:{}", talkRequest.getData(), talkRequest.getMeta());
        List<TalkResponse> talkResponses = protoClient.talkOneAnswerMore(talkRequest);
        talkResponses.forEach(ProtoClient::printResponse);

        log.info("Client streaming RPC");
        protoClient.talkMoreAnswerOne(buildLinkRequests());

        log.info("Bidirectional streaming RPC");
        protoClient.talkBidirectional(buildLinkRequests());
        log.info("==========");
        TimeUnit.SECONDS.sleep(3);
      } while (reconnectAttempts < maxReconnectAttempts);
    } catch (Exception e) {
      ManagedChannel channel = getChannel();
      if (channel == null || channel.isShutdown()) {
        if (reconnect()) {
          talking();
        }
      } else {
        log.error("", e);
      }
    }
  }

  private synchronized boolean reconnect() {
    try {
      if (reconnectAttempts < maxReconnectAttempts) {
        long backoffTime =
            Math.min(
                initialReconnectBackoffMillis
                    * (long) Math.pow(backoffMultiplier, reconnectAttempts),
                maxReconnectBackoffMillis);
        reconnectAttempts++;
        try {
          TimeUnit.MILLISECONDS.sleep(backoffTime);
        } catch (InterruptedException ie) {
          Thread.currentThread().interrupt();
        }
        log.info("Reconnecting to server. Attempt {}", reconnectAttempts);
        this.protoClient.connect(Connection.getChannel());
        return true;
      } else {
        log.error("Max reconnect attempts reached. Exiting.");
        return false;
      }
    } catch (SSLException e) {
      log.error("", e);
      return false;
    }
  }

  public void shutdown() throws InterruptedException {
    this.protoClient.shutdown();
  }
}
