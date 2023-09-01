package org.feuyeux.grpc

import io.grpc.*
import io.grpc.netty.GrpcSslContexts
import io.grpc.netty.NettyServerBuilder
import io.netty.handler.ssl.SslContextBuilder
import org.apache.logging.log4j.kotlin.logger
import org.feuyeux.grpc.conn.Connection
import org.feuyeux.grpc.proto.*
import java.io.File
import java.util.*
import javax.net.ssl.SSLException

//https://myssl.com/create_test_cert.html
const val cert: String = "/var/hello_grpc/server_certs/cert.pem"
const val certKey: String = "/var/hello_grpc/server_certs/private.pkcs8.key"
const val certChain: String = "/var/hello_grpc/server_certs/full_chain.pem"
const val rootCert: String = "/var/hello_grpc/server_certs/myssl_root.cer"

fun main() {
    val server = ProtoServer()
    server.start()
    server.blockUntilShutdown()
}

class ProtoServer {
    private val log = logger()
    private var server: Server? = getServer()
    fun start() {
        server?.start()
        Runtime.getRuntime().addShutdownHook(
                Thread {
                    log.info("*** shutting down gRPC server since JVM is shutting down")
                    this@ProtoServer.stop()
                    log.info("*** server shut down")
                }
        )
    }

    private fun stop() {
        server?.shutdown()
    }

    fun blockUntilShutdown() {
        server?.awaitTermination()
    }

    @Throws(SSLException::class)
    private fun getServer(): Server? {
        val landingService = if (System.getenv("GRPC_HELLO_BACKEND") != null) {
            val channel = Connection.getChannel(HeaderClientInterceptor())
            LandingService(ProtoClient(channel))
        } else {
            LandingService(null)
        }
        val intercept = ServerInterceptors.intercept(landingService, HeaderServerInterceptor())
        val secure = System.getenv("GRPC_HELLO_SECURE")
        val serverPort = System.getenv("GRPC_SERVER_PORT")?.toInt() ?: Connection.port
        return if (secure == null || secure != "Y") {
            log.info("Start GRPC TLS Server[:$serverPort]")
            ServerBuilder.forPort(Connection.port)
                    .addService(intercept)
                    .addTransportFilter(object : ServerTransportFilter() {
                        override fun transportTerminated(transportAttrs: Attributes) {
                            log.warn("GRPC Client {} terminated $transportAttrs.toString()")
                        }
                    })
                    .build()
        } else {
            log.info("Start GRPC TLS Server[:$serverPort]")
            NettyServerBuilder.forPort(Connection.port)
                    .addService(intercept)
                    .sslContext(getSslContextBuilder()?.build())
                    .build()
        }
    }

    private fun getSslContextBuilder(): SslContextBuilder? {
        val sslClientContextBuilder: SslContextBuilder = SslContextBuilder.forServer(File(certChain),
                File(certKey))
        sslClientContextBuilder.trustManager(File(rootCert))
        sslClientContextBuilder.clientAuth(io.netty.handler.ssl.ClientAuth.REQUIRE)
        return GrpcSslContexts.configure(sslClientContextBuilder)
    }
}
