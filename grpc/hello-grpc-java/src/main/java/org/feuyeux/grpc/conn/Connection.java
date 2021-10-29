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

  public static final String GRPC_HELLO_SECURE = "GRPC_HELLO_SECURE";
  public static final String GRPC_SERVER = "GRPC_SERVER";
  public static final String GRPC_SERVER_PORT = "GRPC_SERVER_PORT";
  public static final String GRPC_HELLO_BACKEND = "GRPC_HELLO_BACKEND";
  public static final String GRPC_HELLO_BACKEND_PORT = "GRPC_HELLO_BACKEND_PORT";
  private static final int port = 9996;

  //https://myssl.com/create_test_cert.html
  private static String cert = "/var/hello_grpc/client_certs/cert.pem";
  private static String certKey = "/var/hello_grpc/client_certs/private.pkcs8.key";
  private static String certChain = "/var/hello_grpc/client_certs/full_chain.pem";
  private static String rootCert = "/var/hello_grpc/client_certs/myssl_root.cer";
  private static String serverName = "hello.grpc.io";

  private static String getGrcServerHost() {
    String server = System.getenv(GRPC_SERVER);
    if (server == null) {
      return "localhost";
    }
    return server;
  }

  public static int getGrcServerPort() {
    String currentPort = System.getenv(GRPC_SERVER_PORT);
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
    return System.getenv(GRPC_HELLO_BACKEND);
  }

  public static ManagedChannel getChannel() throws SSLException {
    String connectTo;
    int port;
    String backPort = System.getenv(GRPC_HELLO_BACKEND_PORT);
    if (backPort != null) {
      port = Integer.parseInt(backPort);
    } else {
      port = getGrcServerPort();
    }
    if (hasBackend()) {
      connectTo = getBackend();
    } else {
      connectTo = getGrcServerHost();
    }
    String secure = System.getenv(GRPC_HELLO_SECURE);
    if (secure == null || !secure.equals("Y")) {
      log.info("Connect with InSecure(:{})", port);
      return ManagedChannelBuilder.forAddress(connectTo, port).usePlaintext().build();
    } else {
      log.info("Connect with TLS(:{})", port);
      return NettyChannelBuilder.forAddress(connectTo, port)
          .overrideAuthority(serverName)  /* Only for using provided test certs. */
          .sslContext(buildSslContext())
          .negotiationType(NegotiationType.TLS)
          .build();
    }
  }
}
