package org.feuyeux.grpc

import kotlinx.coroutines.flow.*
import org.apache.logging.log4j.kotlin.logger
import org.feuyeux.grpc.proto.*
import java.util.*

class LandingService(
    private var client: ProtoClient?
) : LandingServiceGrpcKt.LandingServiceCoroutineImplBase() {
    private val log = logger()

    override suspend fun talk(request: TalkRequest): TalkResponse {
        log.info("TALK REQUEST: data=${request.data},meta=${request.meta}")
        return client?.talk(request) ?: TalkResponse.newBuilder()
            .setStatus(200)
            .addResults(buildResult(request.data))
            .build()
    }

    override fun talkOneAnswerMore(request: TalkRequest): Flow<TalkResponse> {
        log.info("TalkOneAnswerMore REQUEST: data=${request.data},meta=${request.meta}")
        return if (client != null) {
            client!!.talkOneAnswerMore(request)
        } else {
            val datas = request.data.split(",").toTypedArray()
            val talkResponses: MutableList<TalkResponse> = mutableListOf()
            for (data in datas) {
                talkResponses.add(
                    TalkResponse.newBuilder()
                        .setStatus(200)
                        .addResults(buildResult(data))
                        .build()
                )
            }
            talkResponses.asFlow()
        }
    }

    override suspend fun talkMoreAnswerOne(requests: Flow<TalkRequest>): TalkResponse {
        return if (client != null) {
            client!!.talkMoreAnswerOne(requests.toList())
        } else {
            val talkResults: MutableList<TalkResult> = mutableListOf()
            requests.collect { request ->
                log.info("TalkMoreAnswerOne REQUEST: data=${request.data},meta=${request.meta}")
                val talkResult = buildResult(request.data)
                talkResults.add(talkResult)
            }
            return TalkResponse.newBuilder()
                .setStatus(200)
                .addAllResults(talkResults)
                .build()
        }
    }

    override fun talkBidirectional(requests: Flow<TalkRequest>): Flow<TalkResponse> = flow {
        if (client != null) {
            //TODO
            requests.collect { request ->
                log.info("TalkBidirectional REQUEST: data=${request.data},meta=${request.meta}")
                emit(
                    talk(request)
                )
            }
        } else {
            requests.collect { request ->
                log.info("TalkBidirectional REQUEST: data=${request.data},meta=${request.meta}")
                emit(
                    TalkResponse.newBuilder()
                        .setStatus(200)
                        .addResults(buildResult(request.data))
                        .build()
                )
            }
        }
    }

    fun buildResult(id: String): TalkResult {
        val index = try {
            id.toInt()
        } catch (ignored: NumberFormatException) {
            0
        }
        val hello: String = if (index > 5) {
            "你好"
        } else {
            Utils.helloList[index]
        }
        val kv: MutableMap<String, String> = HashMap()
        kv["id"] = UUID.randomUUID().toString()
        kv["idx"] = id
        kv["data"] = hello + "," + Utils.match(hello)
        kv["meta"] = "KOTLIN"
        return TalkResult.newBuilder()
            .setId(System.nanoTime())
            .setType(ResultType.OK)
            .putAllKv(kv)
            .build()
    }
}