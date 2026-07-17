package org.feuyeux.grpc.common;

import static com.alibaba.nacos.api.PropertyKeyConst.SERVER_ADDR;
import static org.feuyeux.grpc.common.HelloUtils.getVersion;

import com.alibaba.nacos.api.NacosFactory;
import com.alibaba.nacos.api.naming.NamingService;
import com.alibaba.nacos.api.naming.pojo.Instance;
import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.Client;
import io.etcd.jetcd.lease.LeaseKeepAliveResponse;
import io.etcd.jetcd.options.PutOption;
import io.grpc.*;
import io.grpc.netty.GrpcSslContexts;
import io.grpc.netty.NegotiationType;
import io.grpc.netty.NettyChannelBuilder;
import io.grpc.stub.StreamObserver;
import io.grpc.util.MutableHandlerRegistry;
import io.netty.handler.ssl.SslContext;
import io.netty.handler.ssl.SslContextBuilder;
import java.io.File;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import javax.net.ssl.SSLException;
import org.feuyeux.grpc.discovery.EtcdNameResolverProvider;
import org.feuyeux.grpc.discovery.NacosNameResolverProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Connection {
  private static final Logger log = LoggerFactory.getLogger("Connection");

  public static final String GRPC_HELLO_SECURE = "GRPC_HELLO_SECURE";
  public static final String GRPC_SERVER = "GRPC_SERVER";
  public static final String GRPC_SERVER_PORT = "GRPC_SERVER_PORT";
  public static final String GRPC_HELLO_BACKEND = "GRPC_HELLO_BACKEND";
  public static final String GRPC_HELLO_BACKEND_PORT = "GRPC_HELLO_BACKEND_PORT";
  public static final String GRPC_HELLO_DISCOVERY = "GRPC_HELLO_DISCOVERY";
  public static final String GRPC_HELLO_DISCOVERY_ENDPOINT = "GRPC_HELLO_DISCOVERY_ENDPOINT";

  private static final int port = 9996;

  // https://myssl.com/create_test_cert.html
  private static final String cert = getCertPath("cert.pem");
  private static final String certKey = getCertPath("private.pkcs8.key");
  private static final String certChain = getCertPath("full_chain.pem");
  private static final String rootCert = getCertPath("myssl_root.cer");

  private static String getCertPath(String fileName) {
    // CERT_BASE_PATH points at the directory that contains the client
    // certificates. It takes precedence over the platform defaults.
    String basePath = System.getenv("CERT_BASE_PATH");
    if (basePath != null && !basePath.isEmpty()) {
      return new File(basePath, fileName).getPath();
    }
    String os = System.getProperty("os.name").toLowerCase();
    if (os.contains("win")) {
      return "d:\\garden\\var\\hello_grpc\\client_certs\\" + fileName;
    } else {
      return "/var/hello_grpc/client_certs/" + fileName;
    }
  }

  private static final String serverName = "hello.grpc.io";
  public static final String HELLO_LANDING_SERVICE = "hello.LandingService";

  public static final String server = System.getenv(GRPC_SERVER);
  public static final String currentPort = System.getenv(GRPC_SERVER_PORT);

  public static final String backEnd = System.getenv(GRPC_HELLO_BACKEND);
  public static final String backPort = System.getenv(GRPC_HELLO_BACKEND_PORT);
  public static final String secure = System.getenv(GRPC_HELLO_SECURE);

  /* == discovery == */
  public static final String discovery = System.getenv(GRPC_HELLO_DISCOVERY);
  public static final String discoveryEndpoint = System.getenv(GRPC_HELLO_DISCOVERY_ENDPOINT);

  private static final long TTL = 5L;

  public static final String SVC_DISC_NAME = "hello-grpc";
  /* == discovery == */
  // https://github.com/grpc/grpc/blob/master/doc/load-balancing.md
  public static final String LB_ROUND_ROBIN = "round_robin";
  public static final String LB_PICK_FIRST = "pick_first";

  /**
   * Retry service config for hello.LandingService following gRPC A6 client retries (<a
   * href="https://github.com/grpc/proposal/blob/master/A6-client-retries.md">...</a>).
   */
  private static java.util.Map<String, ?> retryServiceConfig() {
    java.util.Map<String, Object> retryPolicy = new java.util.HashMap<>();
    retryPolicy.put("maxAttempts", 4D);
    retryPolicy.put("initialBackoff", "0.1s");
    retryPolicy.put("maxBackoff", "1s");
    retryPolicy.put("backoffMultiplier", 2D);
    retryPolicy.put("retryableStatusCodes", List.of("UNAVAILABLE"));
    java.util.Map<String, Object> methodConfig = new java.util.HashMap<>();
    methodConfig.put("name", List.of(java.util.Map.of("service", HELLO_LANDING_SERVICE)));
    methodConfig.put("waitForReady", true);
    methodConfig.put("retryPolicy", retryPolicy);
    return java.util.Map.of("methodConfig", List.of(methodConfig));
  }

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
      return !backEnd.isEmpty();
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
    String target = null;
    if (isEtcdDiscovery()) {
      target = "etcd:///" + SVC_DISC_NAME;
      List<URI> endpoints = new ArrayList<>();
      endpoints.add(URI.create(getDiscoveryEndpoint()));
      EtcdNameResolverProvider nameResolver = EtcdNameResolverProvider.forEndpoints(endpoints);
      NameResolverRegistry.getDefaultRegistry().register(nameResolver);
      builder = ManagedChannelBuilder.forTarget(target).defaultLoadBalancingPolicy(LB_ROUND_ROBIN);
    } else if (isNacosDiscovery()) {
      target = "nacos://" + HELLO_LANDING_SERVICE;
      NacosNameResolverProvider nameResolver =
          new NacosNameResolverProvider(URI.create(getDiscoveryEndpoint()));
      NameResolverRegistry.getDefaultRegistry().register(nameResolver);
      builder = ManagedChannelBuilder.forTarget(target).defaultLoadBalancingPolicy(LB_ROUND_ROBIN);
    } else {
      builder = NettyChannelBuilder.forAddress(connectTo, port);
    }
    // Client resilience: HTTP/2 keepalive pings plus transparent retries,
    // mirroring the Go client settings.  keepAliveTime is set to 30s to
    // stay within the PHP gRPC C extension server's default minimum ping
    // interval (GRPC_ARG_HTTP2_MIN_RECV_PING_INTERVAL_WITHOUT_DATA_MS = 30s).
    // Other servers (Java/Go/Python) permit pings as often as 5s, so 30s
    // is a safe common denominator.
    builder
        .keepAliveTime(30, java.util.concurrent.TimeUnit.SECONDS)
        .keepAliveTimeout(5, java.util.concurrent.TimeUnit.SECONDS)
        .keepAliveWithoutCalls(true)
        .defaultServiceConfig(retryServiceConfig())
        .enableRetry();
    if (secure == null || !secure.equals("Y")) {
      if (isDiscovery()) {
        log.info("Connect with InSecure({}) [{}]", target, getVersion());
      } else {
        log.info("Connect with InSecure({}:{}) [{}]", connectTo, port, getVersion());
      }
      return builder.usePlaintext().build();
    } else {
      if (isDiscovery()) {
        log.info("Connect with TLS({}) [{}]", target, getVersion());
      } else {
        log.info("Connect with TLS({}:{}) [{}]", connectTo, port, getVersion());
      }
      return ((NettyChannelBuilder) builder)
          .overrideAuthority(serverName) /* Only for using provided test certs. */
          .sslContext(buildSslContext())
          .negotiationType(NegotiationType.TLS)
          .build();
    }
  }

  // Cross-language compatible etcd key used by the Go/Python/Node.js/TypeScript
  // implementations: a single fixed key (no address suffix) whose value is the
  // plain "host:port" string. Kept alongside the Java-native multi-instance key
  // format below so a Java server registers visibly to every implementation's
  // discovery client, and a Java client can resolve servers started by them.
  private static final String CROSS_LANG_ETCD_KEY = "/etcd/" + SVC_DISC_NAME;

  // Kept alive for the lifetime of the process so the etcd lease keeps renewing;
  // previously this was opened in a try-with-resources that closed the lease
  // client (and the whole etcd Client) immediately after starting the
  // keepAlive stream, cancelling the heartbeat and letting the registration
  // expire after TTL (5s). A single client/lease pair is reused for both the
  // Java-native and cross-language compatible keys below.
  private static volatile Client registrationClient;

  public static void register(io.grpc.BindableService bindableService)
      throws ExecutionException, InterruptedException {
    if (isEtcdDiscovery()) {
      final URI uri = URI.create("http://" + getGrcServerHost() + ":" + getGrcServerPort());
      Client etcd = Client.builder().endpoints(URI.create(getDiscoveryEndpoint())).build();
      registrationClient = etcd;
      long leaseId = etcd.getLeaseClient().grant(TTL).get().getID();

      // Java-native multi-instance key: hello-grpc/<scheme>://<host>:<port>.
      // EtcdNameResolver discovers every instance registered under this prefix.
      ByteSequence javaKey =
          ByteSequence.from(SVC_DISC_NAME + "/" + uri.toASCIIString(), StandardCharsets.US_ASCII);
      ByteSequence javaValue = ByteSequence.from(Long.toString(leaseId), StandardCharsets.US_ASCII);
      PutOption option = PutOption.builder().withLeaseId(leaseId).build();
      etcd.getKVClient().put(javaKey, javaValue, option);

      // Cross-language compatible key: /etcd/hello-grpc -> "host:port", matching
      // the Go/Python/Node.js/TypeScript registration format so this server is
      // discoverable by every implementation's etcd client.
      ByteSequence crossLangKey = ByteSequence.from(CROSS_LANG_ETCD_KEY, StandardCharsets.US_ASCII);
      ByteSequence crossLangValue =
          ByteSequence.from(getGrcServerHost() + ":" + getGrcServerPort(), StandardCharsets.US_ASCII);
      etcd.getKVClient().put(crossLangKey, crossLangValue, option);

      // Single long-lived keepAlive stream renews the lease backing both keys.
      // Do NOT wrap the Lease client (or the etcd Client) in try-with-resources
      // here: closing either immediately cancels this stream.
      etcd.getLeaseClient().keepAlive(
          leaseId,
          new StreamObserver<>() {
            @Override
            public void onNext(LeaseKeepAliveResponse leaseKeepAliveResponse) {
              log.debug("got renewal for lease: {}", leaseKeepAliveResponse.getID());
            }

            @Override
            public void onError(Throwable throwable) {
              log.error("etcd lease keep-alive error", throwable);
            }

            @Override
            public void onCompleted() {
              log.info("lease completed");
            }
          });
    }
    if (isNacosDiscovery()) {
      ServerServiceDefinition serverServiceDefinition = bindableService.bindService();

      try {
        String name = serverServiceDefinition.getServiceDescriptor().getName();
        Properties properties = new Properties();
        properties.put(SERVER_ADDR, getDiscoveryEndpoint());
        NamingService namingService = NacosFactory.createNamingService(properties);

        Instance instance = new Instance();
        instance.setIp(getGrcServerHost());
        instance.setPort(getGrcServerPort());
        namingService.registerInstance(name, instance);

        MutableHandlerRegistry handlerRegistry = new MutableHandlerRegistry();
        handlerRegistry.addService(serverServiceDefinition);
      } catch (Exception e) {
        log.error("Register grpc service error ", e);
      }
    }
  }

  /**
   * Release the etcd client used by {@link #register}, if any. Closing the
   * client revokes its lease (etcd's lease TTL also expires it automatically),
   * removing both the Java-native and cross-language registration keys.
   * Safe to call multiple times or when no etcd registration was made.
   */
  public static void closeRegistration() {
    Client etcd = registrationClient;
    registrationClient = null;
    if (etcd != null) {
      try {
        etcd.close();
      } catch (Exception e) {
        log.warn("Error closing etcd registration client", e);
      }
    }
  }

  private static String getDiscoveryEndpoint() {
    String endpoint;
    if (discoveryEndpoint != null) {
      if (!discoveryEndpoint.startsWith("http://")) {
        endpoint = "http://" + discoveryEndpoint;
      } else {
        endpoint = discoveryEndpoint;
      }
      log.info("DiscoveryEndpoint:{}", endpoint);
      return endpoint;
    }
    return "http://127.0.0.1:2379";
  }

  private static boolean isDiscovery() {
    return isEtcdDiscovery() || isNacosDiscovery();
  }

  private static boolean isEtcdDiscovery() {
    return "etcd".equals(discovery);
  }

  private static boolean isNacosDiscovery() {
    return "nacos".equals(discovery);
  }
}
