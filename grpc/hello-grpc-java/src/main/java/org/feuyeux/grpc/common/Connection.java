package org.feuyeux.grpc.common;

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

  public static String version = "grpc.version=1.49.0,protoc.version=3.21.1,20220913";

  private static final int port = 9996;

  //https://myssl.com/create_test_cert.html
  private static String cert = "/var/hello_grpc/client_certs/cert.pem";
  private static String certKey = "/var/hello_grpc/client_certs/private.pkcs8.key";
  private static String certChain = "/var/hello_grpc/client_certs/full_chain.pem";
  private static String rootCert = "/var/hello_grpc/client_certs/myssl_root.cer";
  private static String serverName = "hello.grpc.io";

  public static String server = System.getenv(GRPC_SERVER);
  public static String currentPort = System.getenv(GRPC_SERVER_PORT);

  public static String backEnd = System.getenv(GRPC_HELLO_BACKEND);
  public static String backPort = System.getenv(GRPC_HELLO_BACKEND_PORT);
  public static String secure = System.getenv(GRPC_HELLO_SECURE);

  public static String PING_TARGET = "etcd:///pingsvc";
  public static String PING_DIR = "pingsvc/";

  private static String getGrcServerHost() {
    if (server == null) {
      return "localhost";
    }
    return server;
  }

  public static int getGrcServerPort() {
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
    if (backEnd == null) {
      return false;
    } else {
      return backEnd.length() > 0;
    }
  }

  public static ManagedChannel getChannel() throws SSLException {
    String connectTo;
    int port;
    if (backPort != null) {
      port = Integer.parseInt(backPort);
    } else {
      port = getGrcServerPort();
    }
    if (hasBackend()) {
      connectTo = backEnd;
    } else {
      connectTo = getGrcServerHost();
    }
    if (secure == null || !secure.equals("Y")) {
      log.info("Connect with InSecure({}:{}) [{}]", connectTo, port, version);
      return ManagedChannelBuilder.forAddress(connectTo, port).usePlaintext().build();
    } else {
      log.info("Connect with TLS({}:{}) [{}]", connectTo, port, version);
      return NettyChannelBuilder.forAddress(connectTo, port)
          .overrideAuthority(serverName)  /* Only for using provided test certs. */
          .sslContext(buildSslContext())
          .negotiationType(NegotiationType.TLS)
          .build();
    }
  }
}
