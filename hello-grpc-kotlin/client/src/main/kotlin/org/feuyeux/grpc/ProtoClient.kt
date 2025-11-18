/**
 * gRPC Client implementation for the Landing service (Kotlin).
 *
 * This client demonstrates all four gRPC communication patterns:
 * 1. Unary RPC
 * 2. Server streaming RPC
 * 3. Client streaming RPC
 * 4. Bidirectional streaming RPC
 *
 * The implementation follows standardized patterns for error handling,
 * logging, and graceful shutdown.
 */

package org.feuyeux.grpc

import io.grpc.ManagedChannel
import io.grpc.StatusException
import kotlinx.coroutines.*
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
import kotlin.system.measureTimeMillis

// Configuration constants
private const val RETRY_ATTEMPTS = 3
private const val RETRY_DELAY_SECONDS = 2L
private const val ITERATION_COUNT = 3
private const val REQUEST_DELAY_MS = 200L
private const val SEND_DELAY_MS = 2L
private const val REQUEST_TIMEOUT_SECONDS = 5L
private const val DEFAULT_BATCH_SIZE = 5

private val logger = logger("ProtoClient")
private var shutdownRequested = false

/**
 * Main entry point for the client
 */
suspend fun main() = coroutineScope {
    setupSignalHandling()
    logger.info("Starting gRPC client [version: ${getVersion()}]")

    // Retry logic for connection
    for (attempt in 1..RETRY_ATTEMPTS) {
        if (shutdownRequested) {
            logger.info("Client shutting down, aborting connection attempts")
            return@coroutineScope
        }

        logger.info("Connection attempt $attempt/$RETRY_ATTEMPTS")

        try {
            val channel = Connection.getChannel(HeaderClientInterceptor())
            ProtoClient(channel).use { client ->
                val success = runGrpcCalls(client, REQUEST_DELAY_MS, ITERATION_COUNT)
                if (success || shutdownRequested) {
                    return@coroutineScope
                }
            }
        } catch (e: Exception) {
            logger.error("Connection attempt $attempt failed: ${e.message}")
            if (attempt < RETRY_ATTEMPTS && !shutdownRequested) {
                logger.info("Retrying in $RETRY_DELAY_SECONDS seconds...")
                delay(RETRY_DELAY_SECONDS * 1000)
            }
        }
    }

    if (shutdownRequested) {
        logger.info("Client execution was cancelled")
    } else {
        logger.info("Client execution completed successfully")
    }
}

/**
 * Set up signal handling for graceful shutdown
 */
private fun setupSignalHandling() {
    Runtime.getRuntime().addShutdownHook(Thread {
        logger.info("Received shutdown signal, cancelling operations")
        shutdownRequested = true
    })
}

/**
 * Run all gRPC call patterns multiple times
 */
private suspend fun runGrpcCalls(
    client: ProtoClient,
    delayMs: Long,
    iterations: Int
): Boolean {
    for (iteration in 1..iterations) {
        if (shutdownRequested) {
            return false
        }

        logger.info("====== Starting iteration $iteration/$iterations ======")

        try {
            // 1. Unary RPC
            logger.info("----- Executing unary RPC -----")
            val unaryRequest = TalkRequest.newBuilder()
                .setData("0")
                .setMeta("KOTLIN")
                .build()
            client.executeUnaryCall(unaryRequest)

            // 2. Server streaming RPC
            logger.info("----- Executing server streaming RPC -----")
            val serverStreamRequest = TalkRequest.newBuilder()
                .setData("0,1,2")
                .setMeta("KOTLIN")
                .build()
            client.executeServerStreamingCall(serverStreamRequest)

            // 3. Client streaming RPC
            logger.info("----- Executing client streaming RPC -----")
            val response = client.executeClientStreamingCall(buildLinkRequests())
            client.logResponse(response)

            // 4. Bidirectional streaming RPC
            logger.info("----- Executing bidirectional streaming RPC -----")
            client.executeBidirectionalStreamingCall(buildLinkRequests())

            if (iteration < iterations && !shutdownRequested) {
                logger.info("Waiting ${delayMs}ms before next iteration...")
                delay(delayMs)
            }
        } catch (e: Exception) {
            logger.error("Error in iteration $iteration: ${e.message}")
            return false
        }
    }

    logger.info("All gRPC calls completed successfully")
    return true
}

/**
 * Build a list of link requests for testing streaming RPCs
 */
private fun buildLinkRequests(): List<TalkRequest> {
    return List(DEFAULT_BATCH_SIZE) {
        TalkRequest.newBuilder()
            .setData((0..5).random().toString())
            .setMeta("KOTLIN")
            .build()
    }
}

/**
 * Get version information
 */
private fun getVersion(): String {
    return "grpc.version=1.0.0" // Placeholder
}

/**
 * Main client class that manages gRPC communication
 */
class ProtoClient(private val channel: ManagedChannel) : Closeable {
    private val logger = logger()
    private val stub = LandingServiceCoroutineStub(channel)
        .withDeadlineAfter(REQUEST_TIMEOUT_SECONDS, TimeUnit.SECONDS)

    override fun close() {
        channel.shutdown().awaitTermination(5, TimeUnit.SECONDS)
        logger.info("Client connection closed")
    }

    /**
     * Execute unary RPC call
     */
    suspend fun executeUnaryCall(request: TalkRequest) {
        val requestId = "unary-${System.currentTimeMillis()}"
        
        logger.info("Sending unary request: data=${request.data}, meta=${request.meta}")
        
        try {
            val duration = measureTimeMillis {
                val response = stub.talk(request)
                logger.info("Unary call successful")
                logResponse(response)
            }
            logger.info("Unary call completed in ${duration}ms")
        } catch (e: StatusException) {
            logError(e, requestId, "Talk")
            throw e
        }
    }

    /**
     * Execute server streaming RPC call
     */
    suspend fun executeServerStreamingCall(request: TalkRequest) {
        val requestId = "server-stream-${System.currentTimeMillis()}"
        
        logger.info("Starting server streaming with request: data=${request.data}, meta=${request.meta}")
        
        try {
            var responseCount = 0
            val duration = measureTimeMillis {
                val responseFlow = stub.talkOneAnswerMore(request)
                responseFlow.collect { response ->
                    if (shutdownRequested) {
                        logger.info("Server streaming cancelled")
                        return@collect
                    }
                    responseCount++
                    logger.info("Received server streaming response #$responseCount:")
                    logResponse(response)
                }
            }
            logger.info("Server streaming completed: received $responseCount responses in ${duration}ms")
        } catch (e: StatusException) {
            logError(e, requestId, "TalkOneAnswerMore")
            throw e
        }
    }

    /**
     * Execute client streaming RPC call
     */
    suspend fun executeClientStreamingCall(requests: List<TalkRequest>): TalkResponse {
        val requestId = "client-stream-${System.currentTimeMillis()}"
        
        logger.info("Starting client streaming with ${requests.size} requests")
        
        try {
            fun listToFlow(rs: List<TalkRequest>): Flow<TalkRequest> = flow {
                var requestCount = 0
                for (r in rs) {
                    if (shutdownRequested) {
                        logger.info("Client streaming cancelled")
                        return@flow
                    }
                    requestCount++
                    logger.info("Sending client streaming request #$requestCount: data=${r.data}, meta=${r.meta}")
                    emit(r)
                    delay(SEND_DELAY_MS)
                }
            }
            
            val startTime = System.currentTimeMillis()
            val response = stub.talkMoreAnswerOne(listToFlow(requests))
            val duration = System.currentTimeMillis() - startTime
            logger.info("Client streaming completed: sent ${requests.size} requests in ${duration}ms")
            return response
        } catch (e: StatusException) {
            logError(e, requestId, "TalkMoreAnswerOne")
            throw e
        }
    }

    /**
     * Execute bidirectional streaming RPC call
     */
    suspend fun executeBidirectionalStreamingCall(requests: List<TalkRequest>) {
        val requestId = "bidirectional-${System.currentTimeMillis()}"
        
        logger.info("Starting bidirectional streaming with ${requests.size} requests")
        
        try {
            var responseCount = 0
            val duration = measureTimeMillis {
                fun listToFlow(rs: List<TalkRequest>): Flow<TalkRequest> = flow {
                    var requestCount = 0
                    for (r in rs) {
                        if (shutdownRequested) {
                            logger.info("Bidirectional streaming cancelled")
                            return@flow
                        }
                        requestCount++
                        logger.info("Sending bidirectional streaming request #$requestCount: data=${r.data}, meta=${r.meta}")
                        emit(r)
                        delay(SEND_DELAY_MS)
                    }
                }
                
                val responseFlow = stub.talkBidirectional(listToFlow(requests))
                responseFlow.collect { response ->
                    if (shutdownRequested) {
                        logger.info("Bidirectional streaming cancelled")
                        return@collect
                    }
                    responseCount++
                    logger.info("Received bidirectional streaming response #$responseCount:")
                    logResponse(response)
                }
            }
            logger.info("Bidirectional streaming completed in ${duration}ms")
        } catch (e: StatusException) {
            logError(e, requestId, "TalkBidirectional")
            throw e
        }
    }

    /**
     * Log response details
     */
    internal fun logResponse(response: TalkResponse) {
        logger.info("Response status: ${response.status}, results: ${response.resultsCount}")
        
        response.resultsList.forEachIndexed { index, result ->
            val kv = result.kvMap
            logger.info("  Result #${index + 1}: id=${result.id}, type=${result.type}, " +
                    "meta=${kv["meta"]}, id=${kv["id"]}, idx=${kv["idx"]}, data=${kv["data"]}")
        }
    }

    /**
     * Log error with context
     */
    private fun logError(error: StatusException, requestId: String, method: String) {
        logger.error("Request failed - request_id: $requestId, method: $method, " +
                "error_code: ${error.status.code}, message: ${error.status.description}")
    }
}
