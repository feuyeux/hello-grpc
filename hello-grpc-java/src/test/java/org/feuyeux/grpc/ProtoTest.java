package org.feuyeux.grpc;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.io.IOException;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.Enumeration;
import java.util.concurrent.ExecutionException;
import org.feuyeux.grpc.client.ProtoClient;
import org.feuyeux.grpc.proto.TalkRequest;
import org.feuyeux.grpc.proto.TalkResponse;
import org.feuyeux.grpc.server.LandingServiceImpl;
import org.feuyeux.grpc.server.ProtoServer;
import org.junit.Rule;
import org.junit.contrib.java.lang.system.EnvironmentVariables;
import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ProtoTest {
  private static final Logger log = LoggerFactory.getLogger("ProtoTest");

  @Rule public final EnvironmentVariables environmentVariables = new EnvironmentVariables();

  public static String getLocalIp() {
    try {
      Enumeration<NetworkInterface> allNetInterfaces = NetworkInterface.getNetworkInterfaces();
      InetAddress ip;
      while (allNetInterfaces.hasMoreElements()) {
        NetworkInterface netInterface = allNetInterfaces.nextElement();
        if ("lo".equals(netInterface.getName())) {
          // 如果是回环网卡跳过
          continue;
        }
        Enumeration<InetAddress> addresses = netInterface.getInetAddresses();
        while (addresses.hasMoreElements()) {
          ip = addresses.nextElement();
          if (ip instanceof Inet4Address) {
            String t = ip.getHostAddress();
            if (!"127.0.0.1".equals(t)) {
              // 只返回不是本地的IP
              return t;
            }
          }
        }
      }
      return null;
    } catch (SocketException e) {
      log.error("", e);
      return null;
    }
  }

  @Test()
  public void testProto() throws InterruptedException, IOException, ExecutionException {
    environmentVariables.set("GRPC_HELLO_SECURE", "Y");
    ProtoServer protoServer = new ProtoServer(new LandingServiceImpl());
    ProtoClient protoClient = new ProtoClient();
    TalkRequest talkRequest =
        TalkRequest.newBuilder().setMeta("id=" + System.nanoTime()).setData("eric").build();
    log.info("REQUEST:{}", talkRequest);
    TalkResponse talkResponse = protoClient.talk(talkRequest);

    assertEquals(200, talkResponse.getStatus());
    log.info("RESPONSE:{}", talkResponse);

    protoClient.shutdown();
    protoServer.stop();
  }
}
