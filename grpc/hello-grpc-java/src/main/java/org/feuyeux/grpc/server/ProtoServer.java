package org.feuyeux.grpc.server;

import static org.feuyeux.grpc.conn.Connection.GRPC_HELLO_SECURE;

import io.grpc.Attributes;
import io.grpc.Channel;
import io.grpc.ClientInterceptors;
import io.grpc.ManagedChannel;
import io.grpc.Server;
import io.grpc.ServerInterceptors;
import io.grpc.ServerServiceDefinition;
import io.grpc.ServerTransportFilter;
import io.grpc.netty.GrpcSslContexts;
import io.grpc.netty.NettyServerBuilder;
import io.grpc.protobuf.services.ProtoReflectionService;
import io.netty.handler.ssl.ClientAuth;
import io.netty.handler.ssl.SslContextBuilder;
import java.io.File;
import java.io.IOException;
import java.util.concurrent.TimeUnit;
import javax.net.ssl.SSLException;
import lombok.extern.slf4j.Slf4j;
import org.feuyeux.grpc.client.HeaderClientInterceptor;
import org.feuyeux.grpc.conn.Connection;
import org.feuyeux.grpc.proto.LandingServiceGrpc;

@Slf4j
public class ProtoServer {

  //https://myssl.com/create_test_cert.html
  private static String cert = "/var/hello_grpc/server_certs/cert.pem";
  private static String certKey = "/var/hello_grpc/server_certs/private.pkcs8.key";
  private static String certChain = "/var/hello_grpc/server_certs/full_chain.pem";
  private static String rootCert = "/var/hello_grpc/server_certs/myssl_root.cer";
  private static ManagedChannel channel;
  private final Server server;

  public ProtoServer(LandingServiceImpl landingService) throws IOException {
    this.server = getServer(landingService);
    start();
  }

  public static void main(String[] args) throws InterruptedException, IOException {
    LandingServiceImpl landingService = new LandingServiceImpl();
    if (Connection.hasBackend()) {
      channel = Connection.getChannel();
      Channel interceptChannel = ClientInterceptors.intercept(channel,
          new HeaderClientInterceptor());
      LandingServiceGrpc.LandingServiceBlockingStub blockingStub = LandingServiceGrpc.newBlockingStub(
          interceptChannel);
      LandingServiceGrpc.LandingServiceStub asyncStub = LandingServiceGrpc.newStub(
          interceptChannel);
      landingService.setAsyncStub(asyncStub);
      landingService.setBlockingStub(blockingStub);
    }
    ProtoServer server = new ProtoServer(landingService);
    server.blockUntilShutdown();
  }

  private Server getServer(LandingServiceImpl landingService) throws SSLException {
    ServerServiceDefinition intercept = ServerInterceptors.intercept(landingService,
        new HeaderServerInterceptor());
    String secure = System.getenv(GRPC_HELLO_SECURE);
    int port = Connection.getGrcServerPort();
    NettyServerBuilder serverBuilder = NettyServerBuilder.forPort(port)
        .addService(intercept)
        .addService(ProtoReflectionService.newInstance())
        .addTransportFilter(new ServerTransportFilter() {
          public void transportTerminated(Attributes transportAttrs) {
            log.warn("GRPC Client {} terminated", transportAttrs.toString());
          }
        });
    if (secure == null || !secure.equals("Y")) {
      log.info("Start GRPC Server[:{}]", port);
      return serverBuilder.build();
    } else {
      log.info("Start GRPC TLS Server[:{}]", port);
      return serverBuilder.sslContext(getSslContextBuilder().build()).build();
    }
  }

  private SslContextBuilder getSslContextBuilder() {
    SslContextBuilder sslClientContextBuilder = SslContextBuilder.forServer(new File(certChain),
        new File(certKey));
    sslClientContextBuilder.trustManager(new File(rootCert));
    sslClientContextBuilder.clientAuth(ClientAuth.REQUIRE);
    return GrpcSslContexts.configure(sslClientContextBuilder);
  }

  private void start() throws IOException {
    server.start();
    Runtime.getRuntime().addShutdownHook(new Thread(() -> {
      log.warn("shutting down Google RPC Server since JVM is shutting down");
      ProtoServer.this.stop();
      log.warn("Google RPC Server shut down");
    }));
  }

  public void blockUntilShutdown() throws InterruptedException {
    if (server != null) {
      server.awaitTermination();
    }
    if (channel != null) {
      channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
    }
  }

  public void stop() {
    server.shutdown();
  }
}
