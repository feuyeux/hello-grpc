package org.feuyeux.grpc

import io.grpc.Context
import io.grpc.Metadata


object Constants {
    private val x_request_id = Metadata.Key.of("x-request-id",
            Metadata.ASCII_STRING_MARSHALLER)
    private val x_b3_traceid = Metadata.Key.of("x-b3-traceid",
            Metadata.ASCII_STRING_MARSHALLER)
    private val x_b3_spanid = Metadata.Key.of("x-b3-spanid",
            Metadata.ASCII_STRING_MARSHALLER)
    private val x_b3_parentspanid = Metadata.Key.of("x-b3-parentspanid",
            Metadata.ASCII_STRING_MARSHALLER)
    private val x_b3_sampled = Metadata.Key.of("x-b3-sampled",
            Metadata.ASCII_STRING_MARSHALLER)
    private val x_b3_flags = Metadata.Key.of("x-b3-flags",
            Metadata.ASCII_STRING_MARSHALLER)
    private val x_ot_span_context = Metadata.Key.of("x-ot-span-context",
            Metadata.ASCII_STRING_MARSHALLER)
    private val context_x_request_id = Context.key<String>("x-request-id")
    private val context_x_b3_traceid = Context.key<String>("x-b3-traceid")
    private val context_x_b3_spanid = Context.key<String>("x-b3-spanid")
    private val context_x_b3_parentspanid = Context.key<String>(
            "x-b3-parentspanid")
    private val context_x_b3_sampled = Context.key<String>("x-b3-sampled")
    private val context_x_b3_flags = Context.key<String>("x-b3-flags")
    private val context_x_ot_span_context = Context.key<String>(
            "x-ot-span-context")
    val tracingKeys: MutableList<Metadata.Key<String>> = mutableListOf()
    val contextKeys: MutableList<Context.Key<String>>? = mutableListOf()

    init {
        tracingKeys!!.add(x_request_id)
        tracingKeys!!.add(x_b3_traceid)
        tracingKeys!!.add(x_b3_spanid)
        tracingKeys!!.add(x_b3_parentspanid)
        tracingKeys!!.add(x_b3_sampled)
        tracingKeys!!.add(x_b3_flags)
        tracingKeys!!.add(x_ot_span_context)

        contextKeys!!.add(context_x_request_id)
        contextKeys!!.add(context_x_b3_traceid)
        contextKeys!!.add(context_x_b3_spanid)
        contextKeys!!.add(context_x_b3_parentspanid)
        contextKeys!!.add(context_x_b3_sampled)
        contextKeys!!.add(context_x_b3_flags)
        contextKeys!!.add(context_x_ot_span_context)
    }
}