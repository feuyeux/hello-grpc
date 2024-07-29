package org.feuyeux.grpc.common;

import static com.alibaba.nacos.api.PropertyKeyConst.SERVER_ADDR;
import static org.feuyeux.grpc.common.HelloUtils.getVersion;

import com.alibaba.nacos.api.NacosFactory;
import com.alibaba.nacos.api.naming.NamingService;
import com.alibaba.nacos.api.naming.pojo.Instance;
import com.google.common.base.Charsets;
import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.Client;
import io.etcd.jetcd.Lease;
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
  private static final String cert = "/var/hello_grpc/client_certs/cert.pem";
  private static final String certKey = "/var/hello_grpc/client_certs/private.pkcs8.key";
  private static final String certChain = "/var/hello_grpc/client_certs/full_chain.pem";
  private static final String rootCert = "/var/hello_grpc/client_certs/myssl_root.cer";
  private static final String serverName = "hello.grpc.io";
  public static final String HELLO_LANDING_SERVICE = "hello.LandingService";

  public static String server = System.getenv(GRPC_SERVER);
  public static String currentPort = System.getenv(GRPC_SERVER_PORT);

  public static String backEnd = System.getenv(GRPC_HELLO_BACKEND);
  public static String backPort = System.getenv(GRPC_HELLO_BACKEND_PORT);
  public static String secure = System.getenv(GRPC_HELLO_SECURE);

  /* == discovery == */
  public static String discovery = System.getenv(GRPC_HELLO_DISCOVERY);
  public static String discoveryEndpoint = System.getenv(GRPC_HELLO_DISCOVERY_ENDPOINT);

  private static final long TTL = 5L;

  public static String SVC_DISC_NAME = "hello-grpc";
  /* == discovery == */
  // https://github.com/grpc/grpc/blob/master/doc/load-balancing.md
  public static final String LB_ROUND_ROBIN = "round_robin";
  public static final String LB_PICK_FIRST = "pick_first";

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

  public static void register(io.grpc.BindableService bindableService)
      throws ExecutionException, InterruptedException {
    if (isEtcdDiscovery()) {
      final URI uri = URI.create("http://" + getGrcServerHost() + ":" + getGrcServerPort());
      Client etcd = Client.builder().endpoints(URI.create(getDiscoveryEndpoint())).build();
      long leaseId = etcd.getLeaseClient().grant(TTL).get().getID();
      ByteSequence key =
          ByteSequence.from(SVC_DISC_NAME + "/" + uri.toASCIIString(), Charsets.US_ASCII);
      ByteSequence value = ByteSequence.from(Long.toString(leaseId), Charsets.US_ASCII);
      PutOption option = PutOption.builder().withLeaseId(leaseId).build();
      etcd.getKVClient().put(key, value, option);
      try (Lease leaseClient = etcd.getLeaseClient()) {
        leaseClient.keepAlive(
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
