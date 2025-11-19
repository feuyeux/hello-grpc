package org.feuyeux.grpc

import kotlinx.coroutines.flow.Flow
import org.feuyeux.grpc.proto.TalkRequest
import org.feuyeux.grpc.proto.TalkResponse

/**
 * Interface for gRPC client proxy/chaining functionality
 */
interface ProtoClient {
    suspend fun talk(request: TalkRequest): TalkResponse
    fun talkOneAnswerMore(request: TalkRequest): Flow<TalkResponse>
    suspend fun talkMoreAnswerOne(requests: List<TalkRequest>): TalkResponse
    fun talkBidirectional(requests: Flow<TalkRequest>): Flow<TalkResponse>
}
