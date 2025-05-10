package org.feuyeux.grpc.conn

import io.grpc.ClientInterceptor
import io.grpc.ManagedChannel
import io.grpc.ManagedChannelBuilder
import io.grpc.netty.GrpcSslContexts
import io.grpc.netty.NegotiationType
import io.grpc.netty.NettyChannelBuilder
import io.netty.handler.ssl.SslContext
import io.netty.handler.ssl.SslContextBuilder
import org.apache.logging.log4j.kotlin.logger
import java.nio.file.Paths
import java.io.File
import javax.net.ssl.SSLException

object Connection {
    private val log = logger()

    //https://myssl.com/create_test_cert.html
    private val certBasePath = getCertBasePath()
    private val cert = Paths.get(certBasePath, "cert.pem").toString()
    private val certKey = Paths.get(certBasePath, "private.pkcs8.key").toString()
    private val certChain = Paths.get(certBasePath, "full_chain.pem").toString()
    private val rootCert = Paths.get(certBasePath, "myssl_root.cer").toString()
    private const val serverName = "hello.grpc.io"
    val port = System.getenv("GRPC_SERVER_PORT")?.toInt() ?: 9996

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
                "d:\\garden\\var\\hello_grpc\\client_certs"
            // macOS
            System.getProperty("os.name").contains("mac", ignoreCase = true) ->
                "/var/hello_grpc/client_certs"
            // Linux and others
            else ->
                "/var/hello_grpc/client_certs"
        }
    }

    init {
        log.info("Using certificate paths: cert=$cert, certKey=$certKey, certChain=$certChain, rootCert=$rootCert")
    }

    @Throws(SSLException::class)
    private fun buildSslContext(): SslContext {
        val builder: SslContextBuilder = GrpcSslContexts.forClient()
        builder.trustManager(File(rootCert))
        builder.keyManager(File(certChain), File(certKey))
        return builder.build()
    }

    fun getChannel(clientInterceptor: ClientInterceptor): ManagedChannel {
        val backend = System.getenv("GRPC_HELLO_BACKEND")
        val grcServer = System.getenv("GRPC_SERVER") ?: "localhost"
        val host = backend ?: grcServer
        val secure = System.getenv("GRPC_HELLO_SECURE")
        val serverPort = getServerPort()
        return if (secure == null || secure != "Y") {
            log.info("Connect With InSecure(:$serverPort)")
            ManagedChannelBuilder.forAddress(host, serverPort)
                .usePlaintext()
                .intercept(clientInterceptor)
                .build()
        } else {
            log.info("Connect With TLS(:$serverPort)")
            NettyChannelBuilder.forAddress(host, serverPort)
                .overrideAuthority(serverName) /* Only for using provided test certs. */
                .sslContext(buildSslContext())
                .negotiationType(NegotiationType.TLS)
                .intercept(clientInterceptor)
                .build()
        }
    }

    fun getServerPort() = (System.getenv("GRPC_HELLO_BACKEND_PORT")?.toInt()
        ?: System.getenv("GRPC_SERVER_PORT")?.toInt() ?: port)
}