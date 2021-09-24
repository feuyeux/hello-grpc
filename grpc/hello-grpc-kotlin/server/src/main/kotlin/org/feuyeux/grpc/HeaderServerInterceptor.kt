package org.feuyeux.grpc

import io.grpc.*
import org.feuyeux.grpc.Constants.contextKeys
import org.feuyeux.grpc.Constants.tracingKeys

class HeaderServerInterceptor : ServerInterceptor {

    override fun <ReqT, RespT> interceptCall(
            call: ServerCall<ReqT, RespT>,
            requestHeaders: Metadata,
            serverCallHandler: ServerCallHandler<ReqT, RespT>): ServerCall.Listener<ReqT> {
        var current = Context.current()
        for (i in 0 until tracingKeys!!.size) {
            val tracingKey: Metadata.Key<String> = tracingKeys!![i]
            val metadata = requestHeaders.get(tracingKey)
            if (metadata != null) {
                val key: Context.Key<String> = contextKeys!![i]
                println("->T ${key}:${metadata}")
                current = current.withValue(key, metadata)
            }
        }
        for (keyName in requestHeaders.keys()) {
            val key = Metadata.Key.of(keyName, Metadata.ASCII_STRING_MARSHALLER)
            val metadata = requestHeaders.get(key)
            println("->H ${key.name()}:${metadata}")
        }
        return Contexts.interceptCall(current, call, requestHeaders, serverCallHandler)
    }
}