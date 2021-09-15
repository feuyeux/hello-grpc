package org.feuyeux.grpc

import io.grpc.ManagedChannel
import io.grpc.ManagedChannelBuilder
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.flow
import org.feuyeux.grpc.proto.LandingServiceGrpcKt.LandingServiceCoroutineStub
import org.feuyeux.grpc.proto.TalkRequest
import org.feuyeux.grpc.proto.TalkResponse
import java.io.Closeable
import java.util.concurrent.TimeUnit

class ProtoClient(private val channel: ManagedChannel) : Closeable {
    private val stub = LandingServiceCoroutineStub(channel)

    override fun close() {
        channel.shutdown().awaitTermination(5, TimeUnit.SECONDS)
    }

    suspend fun talk(talkRequest: TalkRequest): TalkResponse {
        return stub.talk(talkRequest)
    }

    fun talkOneAnswerMore(talkRequest: TalkRequest): Flow<TalkResponse> {
        return stub.talkOneAnswerMore(talkRequest)
    }

    suspend fun talkMoreAnswerOne(talkRequests: List<TalkRequest>): TalkResponse {
        fun listToFlow(rs: List<TalkRequest>): Flow<TalkRequest> = flow {
            for (r in rs) {
                emit(r)
                delay(timeMillis = (5L..10L).random())
            }
        }
        return stub.talkMoreAnswerOne(listToFlow(talkRequests))
    }

    suspend fun talkBidirectional(talkRequests: List<TalkRequest>): Flow<TalkResponse> {
        fun listToFlow(rs: List<TalkRequest>): Flow<TalkRequest> = flow {
            for (r in rs) {
                emit(r)
                delay(timeMillis = 5L)
            }
        }
        return stub.talkBidirectional(listToFlow(talkRequests))
    }
}

suspend fun main() {
    val port = 9996
    val channel = ManagedChannelBuilder.forAddress("localhost", port).usePlaintext().build()

    ProtoClient(channel).use {
        println("Unary RPC")
        var talkRequest: TalkRequest = TalkRequest.newBuilder()
                .setMeta("KOTLIN")
                .setData("0")
                .build()
        val response1: TalkResponse = it.talk(talkRequest)
        printResponse(response1)

        println("Server streaming RPC")
        talkRequest = TalkRequest.newBuilder()
                .setMeta("KOTLIN")
                .setData("0,1,2")
                .build()
        val responseFlow1 = it.talkOneAnswerMore(talkRequest)
        responseFlow1.collect { response2 ->
            printResponse(response2)
        }

        println("Client streaming RPC")
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
        printResponse(response3)

        println("Bidirectional streaming RPC")
        val responseFlow2 = it.talkBidirectional(requests)
        responseFlow2.collect { response4 ->
            printResponse(response4)
        }
    }
}

private fun printResponse(response: TalkResponse) {
    response.resultsList.forEach { result ->
        val kv = result.kvMap
        println("${response.status} ${result.id} [${kv["meta"]} ${result.type} ${kv["id"]}, ${kv["idx"]}:${kv["data"]}]")
    }
}