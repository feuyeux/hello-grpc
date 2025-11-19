package org.feuyeux.grpc

import io.grpc.*
import io.grpc.netty.GrpcSslContexts
import io.grpc.netty.NettyServerBuilder
import io.netty.handler.ssl.ClientAuth
import io.netty.handler.ssl.SslContextBuilder
import org.apache.logging.log4j.kotlin.logger
import org.feuyeux.grpc.conn.Connection
import java.io.File
import java.nio.file.Files
import java.nio.file.Paths
import javax.net.ssl.SSLException

/**
 * Certificate paths for TLS configuration
 */
private val certBasePath = getCertBasePath()
private val certPath = Paths.get(certBasePath, "cert.pem").toString()
private val certKeyPath = Paths.get(certBasePath, "private.pkcs8.key").toString()
private val certChainPath = Paths.get(certBasePath, "full_chain.pem").toString()
private val rootCertPath = Paths.get(certBasePath, "myssl_root.cer").toString()

/**
 * Determines the base directory for TLS certificates based on environment
 * variable or OS-specific default paths.
 *
 * @return The base directory path where certificates are stored
 */
private fun getCertBasePath(): String {
    // Get custom base path from environment variable if set
    val basePath = System.getenv("CERT_BASE_PATH")
    if (!basePath.isNullOrEmpty()) {
        return basePath
    }

    // Use platform-specific default paths
    return when {
        // Windows
        System.getProperty("os.name").contains("win", ignoreCase = true) ->
            "d:\\garden\\var\\hello_grpc\\server_certs"
        // macOS
        System.getProperty("os.name").contains("mac", ignoreCase = true) ->
            "/var/hello_grpc/server_certs"
        // Linux and others
        else ->
            "/var/hello_grpc/server_certs"
    }
}

/**
 * Main entry point for the gRPC server application.
 * Initializes and starts the server with appropriate configuration.
 */
fun main() {
    val logger = logger("ProtoServer")
    
    try {
        logger.info("Using certificate paths: cert=$certPath, key=$certKeyPath, chain=$certChainPath, root=$rootCertPath")
        
        val server = ProtoServer()
        server.start()
        logger.info("Server started successfully")
        server.blockUntilShutdown()
    } catch (e: Exception) {
        logger.error("Failed to start server", e)
        System.exit(1)
    }
}

/**
 * gRPC server implementation for the Landing Service.
 * Supports both secure (TLS) and insecure connections.
 */
class ProtoServer {
    private val logger = logger()
    private val server: Server? by lazy { createServer() }

    /**
     * Gets the gRPC version information for logging purposes.
     *
     * @return A string containing the gRPC version
     */
    fun getVersion(): String = try {
        val version = Package.getPackage("io.grpc")?.implementationVersion ?: "unknown"
        "grpc.version=$version"
    } catch (e: Exception) {
        "grpc.version=unknown"
    }

    /**
     * Starts the server and registers a shutdown hook to handle graceful termination.
     */
    fun start() {
        server?.start()
        
        Runtime.getRuntime().addShutdownHook(Thread {
            logger.info("Shutting down gRPC server due to JVM shutdown")
            this@ProtoServer.stop()
            logger.info("Server shutdown complete")
        })
    }

    /**
     * Stops the server gracefully.
     */
    private fun stop() {
        server?.shutdown()
    }

    /**
     * Blocks until the server shuts down.
     */
    fun blockUntilShutdown() {
        server?.awaitTermination()
    }

    /**
     * Creates a server instance with the specified configuration.
     *
     * @return A configured Server instance
     * @throws SSLException If TLS context setup fails
     */
    @Throws(SSLException::class)
    private fun createServer(): Server? {
        // Create service implementation
        val landingService = LandingService()
        
        // Apply server interceptors
        val interceptedService = ServerInterceptors.intercept(landingService, HeaderServerInterceptor())
        
        // Determine if secure mode is enabled
        val secureMode = System.getenv("GRPC_HELLO_SECURE")
        val serverPort = System.getenv("GRPC_SERVER_PORT")?.toIntOrNull() ?: Connection.port
        
        return if (secureMode != "Y") {
            // Create insecure server
            logger.info("Starting insecure gRPC server on port $serverPort [${getVersion()}]")
            
            ServerBuilder.forPort(serverPort)
                .addService(interceptedService)
                .addTransportFilter(object : ServerTransportFilter() {
                    override fun transportReady(attributes: Attributes): Attributes {
                        logger.info("Connection established: ${attributes.get(Grpc.TRANSPORT_ATTR_REMOTE_ADDR)}")
                        return attributes
                    }
                    
                    override fun transportTerminated(attributes: Attributes) {
                        logger.warn("Connection terminated: ${attributes.get(Grpc.TRANSPORT_ATTR_REMOTE_ADDR)}")
                    }
                })
                .build()
        } else {
            // Create secure server with TLS
            logger.info("Starting secure gRPC server with TLS on port $serverPort [${getVersion()}]")
            
            try {
                // Check if certificate files exist
                validateCertificateFiles()
                
                NettyServerBuilder.forPort(serverPort)
                    .addService(interceptedService)
                    .addTransportFilter(object : ServerTransportFilter() {
                        override fun transportReady(attributes: Attributes): Attributes {
                            logger.info("Connection established: ${attributes.get(Grpc.TRANSPORT_ATTR_REMOTE_ADDR)}")
                            return attributes
                        }
                        
                        override fun transportTerminated(attributes: Attributes) {
                            logger.warn("Connection terminated: ${attributes.get(Grpc.TRANSPORT_ATTR_REMOTE_ADDR)}")
                        }
                    })
                    .sslContext(buildSslContext()?.build())
                    .build()
            } catch (e: Exception) {
                logger.error("TLS configuration failed: ${e.message}. Falling back to insecure mode.")
                
                // Fall back to insecure server if TLS setup fails
                ServerBuilder.forPort(serverPort)
                    .addService(interceptedService)
                    .build()
            }
        }
    }

    /**
     * Validates that the required certificate files exist.
     *
     * @throws IllegalStateException If any required certificate file is missing
     */
    private fun validateCertificateFiles() {
        val certChainFile = File(certChainPath)
        val certKeyFile = File(certKeyPath)
        val rootCertFile = File(rootCertPath)
        
        if (!certChainFile.exists()) {
            throw IllegalStateException("Certificate chain file not found at $certChainPath")
        }
        
        if (!certKeyFile.exists()) {
            throw IllegalStateException("Certificate key file not found at $certKeyPath")
        }
        
        if (!rootCertFile.exists()) {
            throw IllegalStateException("Root certificate file not found at $rootCertPath")
        }
    }

    /**
     * Builds the SSL context for secure connections.
     *
     * @return Configured SSL context builder
     */
    private fun buildSslContext(): SslContextBuilder? {
        val sslContextBuilder = SslContextBuilder.forServer(
            File(certChainPath),
            File(certKeyPath)
        )
        
        sslContextBuilder.trustManager(File(rootCertPath))
        sslContextBuilder.clientAuth(ClientAuth.REQUIRE)
        
        return GrpcSslContexts.configure(sslContextBuilder)
    }
}
