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

import java.io.File
import javax.net.ssl.SSLException

object Connection {
    private val log = logger()

    //https://myssl.com/create_test_cert.html
    private const val cert = "/var/hello_grpc/client_certs/cert.pem"
    private const val certKey = "/var/hello_grpc/client_certs/private.pkcs8.key"
    private const val certChain = "/var/hello_grpc/client_certs/full_chain.pem"
    private const val rootCert = "/var/hello_grpc/client_certs/myssl_root.cer"
    private const val serverName = "hello.grpc.io"
    val port = System.getenv("GRPC_SERVER_PORT")?.toInt() ?: 9996

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