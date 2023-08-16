package org.feuyeux.grpc.common;

import com.google.common.base.Charsets;
import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.Client;
import io.etcd.jetcd.lease.LeaseKeepAliveResponse;
import io.etcd.jetcd.options.PutOption;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.netty.GrpcSslContexts;
import io.grpc.netty.NegotiationType;
import io.grpc.netty.NettyChannelBuilder;
import io.grpc.stub.StreamObserver;
import io.netty.handler.ssl.SslContext;
import io.netty.handler.ssl.SslContextBuilder;
import java.io.File;
import java.net.URI;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutionException;
import javax.net.ssl.SSLException;
import lombok.extern.slf4j.Slf4j;
import org.feuyeux.grpc.etcd.EtcdNameResolverProvider;

@Slf4j
public class Connection {
  public static String version = "grpc.version=1.56.1,protoc.version=3.21.1";

  public static final String GRPC_HELLO_SECURE = "GRPC_HELLO_SECURE";
  public static final String GRPC_SERVER = "GRPC_SERVER";
  public static final String GRPC_SERVER_PORT = "GRPC_SERVER_PORT";
  public static final String GRPC_HELLO_BACKEND = "GRPC_HELLO_BACKEND";
  public static final String GRPC_HELLO_BACKEND_PORT = "GRPC_HELLO_BACKEND_PORT";
  public static final String GRPC_HELLO_DISCOVERY = "GRPC_HELLO_DISCOVERY";
  public static final String GRPC_HELLO_DISCOVERY_ENDPOINT = "GRPC_HELLO_DISCOVERY_ENDPOINT";

  private static final int port = 9996;

  // https://myssl.com/create_test_cert.html
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

  /* == discovery == */
  public static String discovery = System.getenv(GRPC_HELLO_DISCOVERY);
  public static String discoveryEndpoint = System.getenv(GRPC_HELLO_DISCOVERY_ENDPOINT);
  private static final String ENDPOINT = "http://127.0.0.1:2379";
  private static final long TTL = 5L;

  public static String SVC_DISC_NAME = "hello-grpc";
  /* == discovery == */

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
    ManagedChannelBuilder<?> builder;
    String target = "etcd:///" + SVC_DISC_NAME;
    if (isDiscovery()) {
      List<URI> endpoints = new ArrayList<>();
      endpoints.add(URI.create(getDiscoveryEndpoint()));
      EtcdNameResolverProvider nameResolver = EtcdNameResolverProvider.forEndpoints(endpoints);
      builder =
          ManagedChannelBuilder.forTarget(target)
              .nameResolverFactory(nameResolver)
              .defaultLoadBalancingPolicy("round_robin");
    } else {
      builder = NettyChannelBuilder.forAddress(connectTo, port);
    }
    if (secure == null || !secure.equals("Y")) {
      if (isDiscovery()) {
        log.info("Connect with InSecure({}) [{}]", target, version);
      } else {
        log.info("Connect with InSecure({}:{}) [{}]", connectTo, port, version);
      }
      return builder.usePlaintext().build();
    } else {
      if (isDiscovery()) {
        log.info("Connect with TLS({}) [{}]", target, version);
      } else {
        log.info("Connect with TLS({}:{}) [{}]", connectTo, port, version);
      }
      return ((NettyChannelBuilder) builder)
          .overrideAuthority(serverName) /* Only for using provided test certs. */
          .sslContext(buildSslContext())
          .negotiationType(NegotiationType.TLS)
          .build();
    }
  }

  private static String getDiscoveryEndpoint() {
    String endpoint = ENDPOINT;
    if (discoveryEndpoint != null) {
      endpoint = "http://" + discoveryEndpoint;
    }
    log.info("DiscoveryEndpoint:{}", endpoint);
    return endpoint;
  }

  public static void register(Client etcd) throws ExecutionException, InterruptedException {
    if (isDiscovery()) {
      final URI uri = URI.create("http://" + getGrcServerHost() + ":" + getGrcServerPort());
      etcd = Client.builder().endpoints(URI.create(getDiscoveryEndpoint())).build();
      long leaseId = etcd.getLeaseClient().grant(TTL).get().getID();
      ByteSequence key =
          ByteSequence.from(SVC_DISC_NAME + "/" + uri.toASCIIString(), Charsets.US_ASCII);
      ByteSequence value = ByteSequence.from(Long.toString(leaseId), Charsets.US_ASCII);
      PutOption option = PutOption.builder().withLeaseId(leaseId).build();
      etcd.getKVClient().put(key, value, option);
      etcd.getLeaseClient()
          .keepAlive(
              leaseId,
              new StreamObserver<>() {
                @Override
                public void onNext(LeaseKeepAliveResponse leaseKeepAliveResponse) {
                  log.debug("got renewal for lease: " + leaseKeepAliveResponse.getID());
                }

                @Override
                public void onError(Throwable throwable) {
                  log.error("", throwable);
                }

                @Override
                public void onCompleted() {
                  log.info("lease completed");
                }
              });
    }
  }

  private static boolean isDiscovery() {
    return discovery != null && "etcd".equals(discovery);
  }
}
