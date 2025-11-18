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
        log.info("Request fields - data: '${request.data}', meta: '${request.meta}'")
        return try {
            val response = client?.talk(request) ?: TalkResponse.newBuilder()
                .setStatus(200)
                .addResults(buildResult(request.data))
                .build()
            log.info("TALK RESPONSE: status=${response.status}, resultsCount=${response.resultsCount}")
            response
        } catch (e: Exception) {
            log.error("Error in talk method: ${e.message}", e)
            log.error("Error type: ${e.javaClass.name}")
            throw ErrorMapper.toStatusException(e, "talk")
        }
    }

    override fun talkOneAnswerMore(request: TalkRequest): Flow<TalkResponse> {
        log.info("TalkOneAnswerMore REQUEST: data=${request.data},meta=${request.meta}")
        return flow {
            try {
                if (client != null) {
                    client!!.talkOneAnswerMore(request).collect { emit(it) }
                } else {
                    val datas = request.data.split(",").toTypedArray()
                    for (data in datas) {
                        emit(
                            TalkResponse.newBuilder()
                                .setStatus(200)
                                .addResults(buildResult(data))
                                .build()
                        )
                    }
                }
            } catch (e: Exception) {
                log.error("Error in talkOneAnswerMore method", e)
                throw ErrorMapper.toStatusException(e, "")
            }
        }
    }

    override suspend fun talkMoreAnswerOne(requests: Flow<TalkRequest>): TalkResponse {
        return try {
            if (client != null) {
                client!!.talkMoreAnswerOne(requests.toList())
            } else {
                val talkResults: MutableList<TalkResult> = mutableListOf()
                requests.collect { request ->
                    log.info("TalkMoreAnswerOne REQUEST: data=${request.data},meta=${request.meta}")
                    val talkResult = buildResult(request.data)
                    talkResults.add(talkResult)
                }
                TalkResponse.newBuilder()
                    .setStatus(200)
                    .addAllResults(talkResults)
                    .build()
            }
        } catch (e: Exception) {
            log.error("Error in talkMoreAnswerOne method", e)
            throw ErrorMapper.toStatusException(e, "")
        }
    }

    override fun talkBidirectional(requests: Flow<TalkRequest>): Flow<TalkResponse> = flow {
        try {
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
        } catch (e: Exception) {
            log.error("Error in talkBidirectional method", e)
            throw ErrorMapper.toStatusException(e, "")
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