package org.feuyeux.grpc

import io.opentelemetry.api.OpenTelemetry
import io.opentelemetry.api.metrics.LongCounter
import kotlinx.coroutines.flow.*
import org.apache.logging.log4j.kotlin.logger
import org.feuyeux.grpc.proto.*
import java.util.*

class LandingService(openTelemetry: OpenTelemetry = OpenTelemetry.noop()) :
    LandingServiceGrpcKt.LandingServiceCoroutineImplBase() {
    private val log = logger()
    private val rpcCallsCounter: LongCounter = Otel.rpcCallsCounter(openTelemetry)

    override suspend fun talk(request: TalkRequest): TalkResponse {
        log.info("TALK REQUEST: data=${request.data},meta=${request.meta}")
        log.info("Request fields - data: '${request.data}', meta: '${request.meta}'")
        rpcCallsCounter.add(1)
        return try {
            val response = TalkResponse.newBuilder()
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
        rpcCallsCounter.add(1)
        return flow {
            try {
                val datas = request.data.split(",").toTypedArray()
                for (data in datas) {
                    emit(
                        TalkResponse.newBuilder()
                            .setStatus(200)
                            .addResults(buildResult(data))
                            .build()
                    )
                }
            } catch (e: Exception) {
                log.error("Error in talkOneAnswerMore method", e)
                throw ErrorMapper.toStatusException(e, "")
            }
        }
    }

    override suspend fun talkMoreAnswerOne(requests: Flow<TalkRequest>): TalkResponse {
        rpcCallsCounter.add(1)
        return try {
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
        } catch (e: Exception) {
            log.error("Error in talkMoreAnswerOne method", e)
            throw ErrorMapper.toStatusException(e, "")
        }
    }

    override fun talkBidirectional(requests: Flow<TalkRequest>): Flow<TalkResponse> {
        rpcCallsCounter.add(1)
        return flow {
            try {
                requests.collect { request ->
                    log.info("TalkBidirectional REQUEST: data=${request.data},meta=${request.meta}")
                    emit(
                        TalkResponse.newBuilder()
                            .setStatus(200)
                            .addResults(buildResult(request.data))
                            .build()
                    )
                }
            } catch (e: Exception) {
                log.error("Error in talkBidirectional method", e)
                throw ErrorMapper.toStatusException(e, "")
            }
        }
    }

    fun buildResult(id: String): TalkResult {
        val index = id.toIntOrNull()
        require(index != null && index in Utils.helloList.indices) {
            "data must be an integer between 0 and ${Utils.helloList.lastIndex}"
        }
        val hello: String = Utils.helloList[index]
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
