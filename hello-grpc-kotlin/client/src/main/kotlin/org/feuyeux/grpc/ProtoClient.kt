package org.feuyeux.grpc

import io.grpc.ManagedChannel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.flow
import org.apache.logging.log4j.kotlin.logger
import org.feuyeux.grpc.conn.Connection
import org.feuyeux.grpc.proto.LandingServiceGrpcKt.LandingServiceCoroutineStub
import org.feuyeux.grpc.proto.TalkRequest
import org.feuyeux.grpc.proto.TalkResponse
import java.io.Closeable
import java.util.concurrent.TimeUnit

private fun getGrcServer(): String {
    return System.getenv("GRPC_SERVER") ?: return "localhost"
}

suspend fun main() {
    val channel = Connection.getChannel(HeaderClientInterceptor())
    ProtoClient(channel).use {
        var talkRequest: TalkRequest = TalkRequest.newBuilder()
            .setMeta("KOTLIN")
            .setData("0")
            .build()
        val response1: TalkResponse = it.talk(talkRequest)
        it.printResponse(response1)

        talkRequest = TalkRequest.newBuilder()
            .setMeta("KOTLIN")
            .setData("0,1,2")
            .build()
        val responseFlow1 = it.talkOneAnswerMore(talkRequest)
        responseFlow1.collect { response2 ->
            it.printResponse(response2)
        }

        val requests = listOf(
            TalkRequest.newBuilder()
                .setMeta("KOTLIN")
                .setData((0..5).random().toString())
                .build(),
            TalkRequest.newBuilder()
                .setMeta("KOTLIN")
                .setData((0..5).random().toString())
                .build(),
            TalkRequest.newBuilder()
                .setMeta("KOTLIN")
                .setData((0..5).random().toString())
                .build()
        )
        val response3: TalkResponse = it.talkMoreAnswerOne(requests)
        it.printResponse(response3)

        val responseFlow2 = it.talkBidirectional(requests)
        responseFlow2.collect { response4 ->
            it.printResponse(response4)
        }
        // TimeUnit.SECONDS.sleep(5)
    }
}

class ProtoClient(private val channel: ManagedChannel) : Closeable {
    private val logger = logger()
    private val stub = LandingServiceCoroutineStub(channel)

    override fun close() {
        channel.shutdown().awaitTermination(5, TimeUnit.SECONDS)
        logger.info("Done")
    }

    suspend fun talk(talkRequest: TalkRequest): TalkResponse {
        logger.info("Unary RPC")
        return stub.talk(talkRequest)
    }

    fun talkOneAnswerMore(talkRequest: TalkRequest): Flow<TalkResponse> {
        logger.info("Server streaming RPC")
        return stub.talkOneAnswerMore(talkRequest)
    }

    suspend fun talkMoreAnswerOne(talkRequests: List<TalkRequest>): TalkResponse {
        logger.info("Client streaming RPC")
        fun listToFlow(rs: List<TalkRequest>): Flow<TalkRequest> = flow {
            for (r in rs) {
                emit(r)
                delay(timeMillis = (5L..10L).random())
            }
        }
        return stub.talkMoreAnswerOne(listToFlow(talkRequests))
    }

    suspend fun talkBidirectional(talkRequests: List<TalkRequest>): Flow<TalkResponse> {
        logger.info("Bidirectional streaming RPC")
        fun listToFlow(rs: List<TalkRequest>): Flow<TalkRequest> = flow {
            for (r in rs) {
                emit(r)
                delay(timeMillis = 5L)
            }
        }
        return stub.talkBidirectional(listToFlow(talkRequests))
    }

    internal fun printResponse(response: TalkResponse) {
        response.resultsList.forEach { result ->
            val kv = result.kvMap
            logger.info("${response.status} ${result.id} [${kv["meta"]} ${result.type} ${kv["id"]}, ${kv["idx"]}:${kv["data"]}]")
        }
    }
}

