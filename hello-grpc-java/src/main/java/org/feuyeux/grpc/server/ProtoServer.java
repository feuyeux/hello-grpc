package org.feuyeux.grpc.server;

import static org.feuyeux.grpc.common.Connection.*;
import static org.feuyeux.grpc.common.HelloUtils.getVersion;

import io.grpc.Attributes;
import io.grpc.BindableService;
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
import java.nio.file.Paths;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import javax.net.ssl.SSLException;
import org.feuyeux.grpc.client.HeaderClientInterceptor;
import org.feuyeux.grpc.common.Connection;
import org.feuyeux.grpc.proto.LandingServiceGrpc;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * gRPC server implementation for the Landing Service.
 *
 * <p>This server follows the standardized structure:
 *
 * <ol>
 *   <li>Configuration constants
 *   <li>Logger initialization
 *   <li>Certificate path initialization
 *   <li>Server creation with appropriate options
 *   <li>Service registration
 *   <li>Graceful shutdown handling
 * </ol>
 *
 * <p>Supports both secure (TLS) and insecure connections based on environment configuration.
 */
public class ProtoServer {
  private static final Logger log = LoggerFactory.getLogger("ProtoServer");

  // Configuration constants
  private static final long GRACEFUL_SHUTDOWN_TIMEOUT_SECONDS = 10;
  private static final String METRICS_PORT = "9100";

  private static ManagedChannel channel;
  private final Server server;

  // Certificate file paths
  private static final String certPath;
  private static final String certKeyPath;
  private static final String certChainPath;
  private static final String rootCertPath;

  // Initialize certificate paths based on environment or OS
  static {
    String basePath = getCertBasePath();
    certPath = Paths.get(basePath, "cert.pem").toString();
    certKeyPath = Paths.get(basePath, "private.pkcs8.key").toString();
    certChainPath = Paths.get(basePath, "full_chain.pem").toString();
    rootCertPath = Paths.get(basePath, "myssl_root.cer").toString();

    log.debug(
        "Certificate paths initialized: key={}, chain={}, root={}",
        certKeyPath,
        certChainPath,
        rootCertPath);
  }

  /**
   * Gets the base path for TLS certificates based on environment or OS.
   *
   * @return The base directory path where certificates are stored
   */
  private static String getCertBasePath() {
    // Check for environment variable first
    String envPath = System.getenv("CERT_BASE_PATH");
    if (envPath != null && !envPath.isEmpty()) {
      return envPath;
    }

    // Otherwise use OS-specific paths
    String os = System.getProperty("os.name").toLowerCase();
    if (os.contains("win")) {
      return "d:\\garden\\var\\hello_grpc\\server_certs";
    } else if (os.contains("mac")) {
      return "/var/hello_grpc/server_certs";
    } else {
      return "/var/hello_grpc/server_certs";
    }
  }

  /**
   * Creates a new gRPC server with the specified service implementation.
   *
   * @param landingService The service implementation to use
   * @throws IOException If server fails to start
   * @throws ExecutionException If service registration fails
   * @throws InterruptedException If service registration is interrupted
   */
  public ProtoServer(LandingServiceImpl landingService)
      throws IOException, ExecutionException, InterruptedException {
    this.server = createServer(landingService);
    start(landingService);
  }

  /**
   * Server entry point.
   *
   * @param args Command line arguments (not used)
   */
  public static void main(String[] args)
      throws InterruptedException, IOException, ExecutionException {
    log.info("Starting gRPC server [version: {}]", getVersion());

    try {
      // Initialize server implementation
      LandingServiceImpl landingService = createServiceImplementation();

      // Create and start server
      ProtoServer server = new ProtoServer(landingService);
      log.info("Server started successfully");

      // Setup shutdown hook for graceful shutdown
      Runtime.getRuntime()
          .addShutdownHook(
              new Thread(
                  () -> {
                    log.warn("Shutting down gRPC server due to JVM shutdown");
                    server.stop();
                  }));

      server.blockUntilShutdown();
    } catch (Exception e) {
      log.error("Failed to start server", e);
      System.exit(1);
    }
  }

  /**
   * Creates and initializes the gRPC service implementation.
   *
   * @return Initialized LandingServiceImpl instance
   */
  private static LandingServiceImpl createServiceImplementation() {
    LandingServiceImpl landingService = new LandingServiceImpl();

    // Configure backend connection if needed
    if (Connection.hasBackend()) {
      setupBackendConnection(landingService);
    }

    return landingService;
  }

  /**
   * Sets up the connection to a backend service.
   *
   * @param landingService The service implementation that will use the backend
   */
  private static void setupBackendConnection(LandingServiceImpl landingService) {
    try {
      channel = Connection.getChannel();
      Channel interceptChannel =
          ClientInterceptors.intercept(channel, new HeaderClientInterceptor());

      // Create stubs for backend communication
      LandingServiceGrpc.LandingServiceBlockingStub blockingStub =
          LandingServiceGrpc.newBlockingStub(interceptChannel);
      LandingServiceGrpc.LandingServiceStub asyncStub =
          LandingServiceGrpc.newStub(interceptChannel);

      landingService.setAsyncStub(asyncStub);
      landingService.setBlockingStub(blockingStub);

      log.info("Backend connection established");
    } catch (Exception e) {
      log.error("Failed to connect to backend", e);
    }
  }

  /**
   * Creates a server instance with the specified service implementation.
   *
   * @param landingService The service implementation to use
   * @return A configured Server instance
   * @throws SSLException If TLS context setup fails
   */
  private Server createServer(LandingServiceImpl landingService) throws SSLException {
    // Apply server interceptors to the service
    ServerServiceDefinition interceptedService =
        ServerInterceptors.intercept(landingService, new HeaderServerInterceptor());

    // Determine if secure mode is enabled
    String secureMode = System.getenv(GRPC_HELLO_SECURE);
    int port = Connection.getGrcServerPort();

    // Configure the server builder
    NettyServerBuilder serverBuilder =
        NettyServerBuilder.forPort(port)
            .addService(interceptedService)
            .addService(ProtoReflectionService.newInstance())
            .addTransportFilter(
                new ServerTransportFilter() {
                  @Override
                  public Attributes transportReady(Attributes transportAttrs) {
                    log.info("New client connection established: {}", transportAttrs);
                    return transportAttrs;
                  }

                  @Override
                  public void transportTerminated(Attributes transportAttrs) {
                    log.warn("Client connection terminated: {}", transportAttrs);
                  }
                });

    // Build server with or without TLS
    if (secureMode != null && secureMode.equals("Y")) {
      log.info("Starting gRPC TLS server on port {} [version: {}]", port, getVersion());
      return serverBuilder.sslContext(buildSslContext()).build();
    } else {
      log.info("Starting gRPC server on port {} [version: {}]", port, getVersion());
      return serverBuilder.build();
    }
  }

  /**
   * Builds the SSL context for secure connections.
   *
   * @return Configured SSL context
   * @throws SSLException If SSL context creation fails
   */
  private io.netty.handler.ssl.SslContext buildSslContext() throws SSLException {
    try {
      // Create SSL context with server certificate and private key
      SslContextBuilder sslContextBuilder =
          SslContextBuilder.forServer(new File(certChainPath), new File(certKeyPath));

      // Configure trust manager and client authentication
      sslContextBuilder.trustManager(new File(rootCertPath));
      sslContextBuilder.clientAuth(ClientAuth.REQUIRE);

      return GrpcSslContexts.configure(sslContextBuilder).build();
    } catch (Exception e) {
      log.error("Failed to build SSL context: {}", e.getMessage());
      throw new SSLException("SSL context creation failed", e);
    }
  }

  /**
   * Starts the server and registers the service.
   *
   * @param service The service to register
   * @throws IOException If server start fails
   * @throws ExecutionException If service registration fails
   * @throws InterruptedException If service registration is interrupted
   */
  private void start(BindableService service)
      throws IOException, ExecutionException, InterruptedException {
    server.start();
    register(service);
  }

  /** Stops the server and releases resources with graceful shutdown. */
  public void stop() {
    log.info("Initiating graceful shutdown...");

    if (server != null) {
      try {
        // Attempt graceful shutdown
        server.shutdown();
        if (!server.awaitTermination(GRACEFUL_SHUTDOWN_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
          log.warn("Graceful shutdown timed out, forcing server stop");
          server.shutdownNow();
        } else {
          log.info("Server stopped gracefully");
        }
      } catch (InterruptedException e) {
        log.warn("Server shutdown interrupted, forcing stop");
        server.shutdownNow();
        Thread.currentThread().interrupt();
      }
    }

    if (channel != null) {
      try {
        channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
      } catch (InterruptedException e) {
        log.warn("Channel shutdown interrupted");
        channel.shutdownNow();
        Thread.currentThread().interrupt();
      }
    }

    log.info("Server shutdown complete");
  }

  /**
   * Blocks until the server shuts down.
   *
   * @throws InterruptedException If thread is interrupted while waiting
   */
  public void blockUntilShutdown() throws InterruptedException {
    if (server != null) {
      server.awaitTermination();
    }
  }
}
