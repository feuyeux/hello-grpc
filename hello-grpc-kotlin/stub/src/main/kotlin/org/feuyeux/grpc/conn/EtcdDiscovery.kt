package org.feuyeux.grpc.conn

import kotlinx.coroutines.*
import org.apache.logging.log4j.kotlin.logger
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration

/**
 * etcd v3 service discovery via HTTP API.
 *
 * Uses the etcd v3 gRPC-gateway HTTP endpoint to register and resolve
 * service instances without requiring a native etcd client library.
 *
 * Env vars:
 *   GRPC_HELLO_DISCOVERY=etcd        enable discovery
 *   GRPC_HELLO_DISCOVERY_ENDPOINT    etcd endpoint (default http://127.0.0.1:2379)
 */
object EtcdDiscovery {
    private val log = logger()
    private const val SVC_DISC_NAME = "hello-grpc"
    private const val ETCD_KEY = "/etcd/hello-grpc"
    private const val DEFAULT_TTL = 5L

    private val httpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(5))
        .build()

    private fun getEndpoint(): String {
        var ep = System.getenv("GRPC_HELLO_DISCOVERY_ENDPOINT") ?: "http://127.0.0.1:2379"
        if (!ep.startsWith("http://") && !ep.startsWith("https://")) {
            ep = "http://$ep"
        }
        return ep
    }

    private fun post(path: String, payload: Map<String, Any>): Map<String, Any?> {
        val url = getEndpoint() + path
        val body = jacksonObjectMapper().writeValueAsString(payload)
        val request = HttpRequest.newBuilder()
            .uri(URI.create(url))
            .header("Content-Type", "application/json")
            .timeout(Duration.ofSeconds(5))
            .POST(HttpRequest.BodyPublishers.ofString(body))
            .build()
        val response = httpClient.send(request, HttpResponse.BodyHandlers.ofString())
        if (response.statusCode() >= 400) {
            throw RuntimeException("etcd request failed: $path (HTTP ${response.statusCode()})")
        }
        return jacksonObjectMapper().readValue(response.body(), Map::class.java) as Map<String, Any?>
    }

    private fun b64(s: String): String = java.util.Base64.getEncoder().encodeToString(s.toByteArray())
    private fun b64Decode(s: String): String = String(java.util.Base64.getDecoder().decode(s))

    fun isEtcdDiscovery(): Boolean = "etcd" == System.getenv("GRPC_HELLO_DISCOVERY")

    fun resolveFromEtcd(): String? {
        val resp = post("/v3/kv/range", mapOf("key" to b64(ETCD_KEY)))
        val kvs = resp["kvs"] as? List<*> ?: return null
        if (kvs.isEmpty()) return null
        val kv = kvs[0] as Map<*, *>
        val value = kv["value"] as? String ?: return null
        return b64Decode(value)
    }

    fun registerToEtcd(host: String, port: Int): Job {
        val address = "$host:$port"
        // Grant lease
        val leaseResp = post("/v3/lease/grant", mapOf("TTL" to DEFAULT_TTL))
        val leaseId = (leaseResp["ID"]?.toString() ?: "0")
        if (leaseId == "0") {
            throw RuntimeException("etcd lease grant failed: $leaseResp")
        }
        // Put key with lease
        post("/v3/kv/put", mapOf(
            "key" to b64(ETCD_KEY),
            "value" to b64(address),
            "lease" to leaseId,
        ))
        log.info("Registered with etcd: $address (lease=$leaseId)")
        // Start keepalive coroutine
        return GlobalScope.launch {
            while (isActive) {
                delay((DEFAULT_TTL - 1) * 1000)
                try {
                    post("/v3/lease/keepalive", mapOf("ID" to leaseId))
                } catch (e: Exception) {
                    log.warn("etcd keepalive error: ${e.message}")
                }
            }
        }
    }
}

// Helper to access Jackson ObjectMapper (already a dependency in the project)
private fun jacksonObjectMapper() = com.fasterxml.jackson.module.kotlin.jacksonObjectMapper()
