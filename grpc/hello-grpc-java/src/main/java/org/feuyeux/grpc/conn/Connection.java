package org.feuyeux.grpc.conn;

import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.netty.GrpcSslContexts;
import io.grpc.netty.NegotiationType;
import io.grpc.netty.NettyChannelBuilder;
import io.netty.handler.ssl.SslContext;
import io.netty.handler.ssl.SslContextBuilder;
import java.io.File;
import javax.net.ssl.SSLException;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class Connection {

  //https://myssl.com/create_test_cert.html
  private static String cert = "/var/hello_grpc/client_certs/cert.pem";
  private static String certKey = "/var/hello_grpc/client_certs/private.pkcs8.key";
  private static String certChain = "/var/hello_grpc/client_certs/full_chain.pem";
  private static String rootCert = "/var/hello_grpc/client_certs/myssl_root.cer";
  private static String serverName = "hello.grpc.io";
  private static int port = 9996;

  private static String getGrcServer() {
    String server = System.getenv("GRPC_SERVER");
    if (server == null) {
      return "localhost";
    }
    return server;
  }

  public static int getPort() {
    String currentPort = System.getenv("GRPC_HELLO_PORT");
    if (currentPort == null) {
      return port;
    } else {
      return Integer.parseInt(currentPort);
    }
  }

  private static SslContext buildSslContext() throws SSLException {
    SslContextBuilder builder = GrpcSslContexts.forClient();
    builder.trustManager(new File(rootCert));
    builder.keyManager(new File(certChain), new File(certKey));
    return builder.build();
  }

  public static boolean hasBackend() {
    if (getBackend() == null) {
      return false;
    } else {
      return getBackend().length() > 0;
    }
  }

  private static String getBackend() {
    return System.getenv("GRPC_HELLO_BACKEND");
  }

  public static ManagedChannel getChannel() throws SSLException {
    String host;
    int port;
    String backPort = System.getenv("GRPC_HELLO_BACKEND_PORT");
    if (backPort != null) {
      port = Integer.parseInt(backPort);
    } else {
      port = getPort();
    }
    if (hasBackend()) {
      host = getBackend();
    } else {
      host = getGrcServer();
    }
    String secure = System.getenv("GRPC_HELLO_SECURE");
    if (secure == null || !secure.equals("Y")) {
      log.info("Connect With InSecure");
      return ManagedChannelBuilder.forAddress(host, port).usePlaintext().build();
    } else {
      log.info("Connect With TLS");
      return NettyChannelBuilder.forAddress(host, port)
          .overrideAuthority(serverName)  /* Only for using provided test certs. */
          .sslContext(buildSslContext())
          .negotiationType(NegotiationType.TLS)
          .build();
    }
  }
}
