package org.feuyeux.grpc

import io.grpc.*
import io.grpc.ForwardingClientCall.SimpleForwardingClientCall
import io.grpc.ForwardingClientCallListener.SimpleForwardingClientCallListener
import org.feuyeux.grpc.Constants.contextKeys
import org.feuyeux.grpc.Constants.tracingKeys


class HeaderClientInterceptor : ClientInterceptor {
    override fun <ReqT, RespT> interceptCall(method: MethodDescriptor<ReqT, RespT>?,
                                             callOptions: CallOptions?, next: Channel): ClientCall<ReqT, RespT> {
        return object : SimpleForwardingClientCall<ReqT, RespT>(next.newCall(method, callOptions)) {
            override fun start(responseListener: Listener<RespT>?, headers: Metadata) {
                for (i in tracingKeys.indices) {
                    val k = contextKeys!![i]
                    if (k.get() != null) {
                        val metadata = k.get()
                        val key = tracingKeys[i]
                        println("<-T ${key.name()}:${metadata}")
                        headers.put(key, metadata)
                    }
                }
                super.start(object : SimpleForwardingClientCallListener<RespT>(
                        responseListener) {
                    override fun onHeaders(headers: Metadata?) {
                        println("<-H $headers")
                        super.onHeaders(headers)
                    }
                }, headers)
            }
        }
    }
}