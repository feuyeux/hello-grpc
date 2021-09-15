package org.feuyeux.grpc

import io.grpc.Server
import io.grpc.ServerBuilder
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.asFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.flow
import org.feuyeux.grpc.proto.*
import java.util.*


class ProtoServer(
        private val port: Int,
        private val server: Server = ServerBuilder.forPort(port).addService(LandingService()).build()
) {
    fun start() {
        server.start()
        println("Server started, listening on $port")
        Runtime.getRuntime().addShutdownHook(
                Thread {
                    println("*** shutting down gRPC server since JVM is shutting down")
                    this@ProtoServer.stop()
                    println("*** server shut down")
                }
        )
    }

    private fun stop() {
        server.shutdown()
    }

    fun blockUntilShutdown() {
        server.awaitTermination()
    }

    class LandingService(
    ) : LandingServiceGrpcKt.LandingServiceCoroutineImplBase() {
        private val helloList = listOf("Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요")

        override suspend fun talk(request: TalkRequest): TalkResponse {
            println("TALK REQUEST: data=${request.data},meta=${request.meta}")
            return TalkResponse.newBuilder()
                    .setStatus(200)
                    .addResults(buildResult(request.data))
                    .build()
        }

        override fun talkOneAnswerMore(request: TalkRequest): Flow<TalkResponse> {
            println("TalkOneAnswerMore REQUEST: data=${request.data},meta=${request.meta}")
            val datas = request.data.split(",").toTypedArray()
            val talkResponses: MutableList<TalkResponse> = mutableListOf()
            for (data in datas) {
                talkResponses.add(TalkResponse.newBuilder()
                        .setStatus(200)
                        .addResults(buildResult(data))
                        .build())
            }
            return talkResponses.asFlow()
        }

        override suspend fun talkMoreAnswerOne(requests: Flow<TalkRequest>): TalkResponse {
            val talkResults: MutableList<TalkResult> = mutableListOf()
            requests.collect { request ->
                println("TalkMoreAnswerOne REQUEST: data=${request.data},meta=${request.meta}")
                val talkResult = buildResult(request.data)
                talkResults.add(talkResult)
            }
            return TalkResponse.newBuilder()
                    .setStatus(200)
                    .addAllResults(talkResults)
                    .build()
        }

        override fun talkBidirectional(requests: Flow<TalkRequest>): Flow<TalkResponse> = flow {
            requests.collect { request ->
                println("TalkBidirectional REQUEST: data=${request.data},meta=${request.meta}")
                emit(TalkResponse.newBuilder()
                        .setStatus(200)
                        .addResults(buildResult(request.data))
                        .build())
            }
        }

        private fun buildResult(id: String): TalkResult {
            val index = try {
                id.toInt()
            } catch (ignored: NumberFormatException) {
                0
            }
            val data = if (index > 5) {
                "你好"
            } else {
                helloList[index]
            }
            val kv: MutableMap<String, String> = HashMap()
            kv["id"] = UUID.randomUUID().toString()
            kv["idx"] = id
            kv["data"] = data
            kv["meta"] = "KOTLIN"
            return TalkResult.newBuilder()
                    .setId(System.nanoTime())
                    .setType(ResultType.OK)
                    .putAllKv(kv)
                    .build()
        }
    }
}

fun main() {
    val port = 9996
    val server = ProtoServer(port)
    server.start()
    server.blockUntilShutdown()
}
