/**
 * gRPC Server Implementation for Node.js
 * 
 * This server implements all four types of gRPC service patterns:
 * - Unary RPC (talk)
 * - Server Streaming RPC (talkOneAnswerMore)
 * - Client Streaming RPC (talkMoreAnswerOne)
 * - Bidirectional Streaming RPC (talkBidirectional)
 * 
 * Features:
 * - TLS support with automatic certificate loading
 * - Graceful shutdown with proper signal handling
 * - Backend service proxying
 * - Comprehensive error handling and logging
 * - Tracing header propagation
 */

const grpc = require("@grpc/grpc-js")
const protoLoader = require('@grpc/proto-loader');
const { ReflectionService } = require('@grpc/reflection');
const { otelEnabled, initOtel, getCounter } = require("../common/otel")
const uuid = require('uuid');
const { TalkResult, TalkResponse, ResultType } = require('../proto/landing_pb');
const services = require('../proto/landing_grpc_pb');
const conn = require('../common/connection');
const utils = require('../common/utils');
const { isEtcdDiscovery, registerToEtcd } = require('../common/etcd_discovery');
const { toGrpcError } = require('../common/error_mapper');
// B7 — gRPC Health Check
// grpc-health-check v2.x changed the API: there is no `HealthCheckResponse`
// enum and `ServingStatus` is now a string-union type, not an object. Pass
// the literal `'SERVING'` directly into the status map instead of digging
// it out of a nested enum.
const { HealthImplementation } = require('grpc-health-check');
// C5 — Logging middleware
const { withLogging } = require('../common/interceptor');
const { parseDataIndex } = require('../common/validation');

const fs = require('fs');
const path = require('path');
const os = require('os');

// Headers that should be propagated to backend services for tracing purposes
const tracingHeaders = [
    "x-request-id",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-ot-span-context"
];

// Set up logger
const logger = conn.logger;

// Initialize OpenTelemetry when GRPC_HELLO_OTEL=Y. The instrumentation
// patches @grpc/grpc-js's Server.register globally, so initOtel must
// run before any grpc.Server instance is constructed below. No-op when
// the env var is unset.
if (otelEnabled()) {
    initOtel("hello-grpc-nodejs-server");
}
const rpcCallsTotal = getCounter(
    "rpc_calls_total",
    "Total number of gRPC calls handled"
);

function recordRpcCall(methodName) {
    if (!rpcCallsTotal) return;
    rpcCallsTotal.add(1, {
        "rpc.system": "grpc",
        "rpc.service": "LandingService",
        "rpc.method": methodName
    });
}

// Backend client instance
let backendClient = null;

/**
 * Get the base path for certificate files based on the current platform
 * @returns {string} The base path for certificate files
 */
function getCertBasePath() {
    const platform = os.platform();
    if (process.env.CERT_BASE_PATH) {
        return process.env.CERT_BASE_PATH;
    } else if (platform === 'win32') {
        // Windows path
        return "d:\\garden\\var\\hello_grpc\\server_certs";
    } else if (platform === 'darwin') {
        // macOS path
        return "/var/hello_grpc/server_certs";
    } else {
        // Linux/Unix path
        return "/var/hello_grpc/server_certs";
    }
}

// Get certificate base path
const certBasePath = getCertBasePath();

// Define certificate paths
const certPath = path.join(certBasePath, "cert.pem");
const certKeyPath = path.join(certBasePath, "private.key");
const certChainPath = path.join(certBasePath, "full_chain.pem");

/**
 * Starts an RPC server that receives requests for the LandingService
 */
async function main() {
    logger.info("Starting gRPC server with Node.js implementation");

    // Initialize backend client if configured
    if (hasBackend()) {
        backendClient = await conn.getClient();
        logger.info("Backend client initialized for proxying requests");
    }

    // Get server port from environment variable or use default
    const port = process.env.GRPC_SERVER_PORT || "9996";
    const address = "0.0.0.0:" + port;

    // Register with etcd if discovery is enabled
    let etcdCleanup = null;
    if (isEtcdDiscovery()) {
        const host = process.env.GRPC_SERVER || 'localhost';
        etcdCleanup = await registerToEtcd(host, parseInt(port, 10));
        global.__etcdCleanup = etcdCleanup;
        logger.info("Registered with etcd service discovery");
    }

    // Create new gRPC server
    const server = new grpc.Server();

    // B7 — Health check
    const statusMap = { '': 'SERVING' };
    const healthImpl = new HealthImplementation(statusMap);
    healthImpl.addToServer(server);

    // Add service implementation (C5 — wrap with logging middleware)
    server.addService(services.LandingServiceService, withLogging({
        talk: talk,
        talkOneAnswerMore: talkOneAnswerMore,
        talkMoreAnswerOne: talkMoreAnswerOne,
        talkBidirectional: talkBidirectional
    }));

    // C4 — gRPC Server Reflection. The official implementation consumes the
    // proto-loader package definition so it can expose file descriptors.
    new ReflectionService(loadLandingPackageDefinition()).addToServer(server);

    // Set up signal handlers for graceful shutdown
    setupSignalHandlers(server);

    // Check if we should use TLS
    const secure = process.env.GRPC_HELLO_SECURE;
    if (secure === "Y") {
        startSecureServer(server, address);
    } else {
        startInsecureServer(server, address);
    }
}

function loadLandingPackageDefinition() {
    const candidates = [
        path.resolve(__dirname, '../../../proto/landing.proto'),
        path.resolve(process.cwd(), 'proto/landing.proto')
    ];
    const protoPath = candidates.find(candidate => fs.existsSync(candidate));
    if (!protoPath) {
        throw new Error(`landing.proto not found; checked: ${candidates.join(', ')}`);
    }
    return protoLoader.loadSync(protoPath);
}

/**
 * Set up signal handlers for graceful shutdown
 * @param {grpc.Server} server The gRPC server instance
 */
function setupSignalHandlers(server) {
    // Handle SIGINT (Ctrl+C)
    process.on('SIGINT', () => {
        logger.info("Received SIGINT signal, shutting down server...");
        gracefulShutdown(server);
    });

    // Handle SIGTERM
    process.on('SIGTERM', () => {
        logger.info("Received SIGTERM signal, shutting down server...");
        gracefulShutdown(server);
    });
}

/**
 * Gracefully shut down the server
 * @param {grpc.Server} server The gRPC server instance
 */
function gracefulShutdown(server) {
    logger.info("Starting graceful shutdown...");

    // Try graceful shutdown with timeout
    const forceShutdownTimeout = setTimeout(() => {
        logger.warn("Graceful shutdown timed out, forcing exit");
        process.exit(1);
    }, 10000); // 10 seconds timeout

    server.tryShutdown(() => {
        clearTimeout(forceShutdownTimeout);
        // Clean up etcd registration if active
        if (global.__etcdCleanup) {
            global.__etcdCleanup();
        }
        logger.info("Server shutdown complete");
        process.exit(0);
    });
}

/**
 * Start the server with TLS enabled
 * @param {grpc.Server} server The gRPC server instance
 * @param {string} address The server address to bind to
 */
function startSecureServer(server, address) {
    try {
        logger.info("TLS is enabled, configuring secure server");

        // Validate certificate files
        if (!fs.existsSync(certPath)) {
            logger.error(`Certificate file not found: ${certPath}`);
            throw new Error(`Certificate file not found: ${certPath}`);
        }

        if (!fs.existsSync(certKeyPath)) {
            logger.error(`Private key file not found: ${certKeyPath}`);
            throw new Error(`Private key file not found: ${certKeyPath}`);
        }

        // Read certificates - use full_chain.pem for complete certificate chain
        const certChainContent = fs.existsSync(certChainPath) ? fs.readFileSync(certChainPath) : fs.readFileSync(certPath);
        const privateKeyContent = fs.readFileSync(certKeyPath);

        logger.info("Using certificate chain from: %s", fs.existsSync(certChainPath) ? certChainPath : certPath);

        // Create TLS credentials. The default is one-way TLS (server only);
        // setting GRPC_HELLO_REQUIRE_CLIENT_CERT=Y switches to mutual TLS
        // by requiring (and verifying, against the bundled client CA) a
        // client-side cert on every connection.
        const requireClientCert = process.env.GRPC_HELLO_REQUIRE_CLIENT_CERT === "Y";
        const clientRootCert = requireClientCert
            ? fs.readFileSync(path.join(
                certBasePath.replace(/server_certs$/, "client_certs"),
                "myssl_root.cer"
            ))
            : null;
        const credentials = grpc.ServerCredentials.createSsl(
            clientRootCert,  // root CAs for client-cert verification (null = no client auth)
            [{
                cert_chain: certChainContent,
                private_key: privateKeyContent
            }],
            requireClientCert
        );

        server.bindAsync(address, credentials, (err, port) => {
            if (err) {
                handleSecureServerFailure(server, address, err, "Failed to bind TLS server");
            } else {
                logger.info("Start GRPC TLS Server on port %s [%s]", port, utils.getVersion());
            }
        });
    } catch (err) {
        handleSecureServerFailure(server, address, err, "Failed to start TLS server");
    }
}

/**
 * Handle a TLS setup/bind failure. Fails fast by default (exits the process)
 * so a broken certificate configuration never results in an unnoticed
 * plaintext listener. Only falls back to an insecure server when the
 * operator has explicitly opted in via GRPC_HELLO_INSECURE_FALLBACK=Y,
 * matching the Go/Python/Java implementations' behavior.
 * @param {grpc.Server} server The gRPC server instance
 * @param {string} address The server address to bind to
 * @param {Error} err The error that triggered the failure
 * @param {string} context A short description of what failed, for logging
 */
function handleSecureServerFailure(server, address, err, context) {
    logger.error("%s: %s", context, err && err.message ? err.message : err);
    if (process.env.GRPC_HELLO_INSECURE_FALLBACK === "Y") {
        logger.warn("GRPC_HELLO_INSECURE_FALLBACK=Y - falling back to insecure server");
        startInsecureServer(server, address);
        return;
    }
    logger.error("TLS was requested but could not be configured. Set CERT_BASE_PATH to the " +
        "certificate directory, or set GRPC_HELLO_INSECURE_FALLBACK=Y to explicitly allow " +
        "an insecure server.");
    process.exit(1);
}

/**
 * Start the server with TLS disabled
 * @param {grpc.Server} server The gRPC server instance
 * @param {string} address The server address to bind to
 */
function startInsecureServer(server, address) {
    logger.info("Starting insecure gRPC server");

    server.bindAsync(address, grpc.ServerCredentials.createInsecure(), (err, port) => {
        if (err) {
            logger.error("Failed to bind insecure server:", err);
            process.exit(1);
        }
        logger.info("Start GRPC Server on port %s [%s]", port, utils.getVersion());
    });
}

/**
 * Unary RPC method implementation
 * @param {Object} call The gRPC call object
 * @param {Function} callback Callback to return the response
 */
function talk(call, callback) {
    recordRpcCall("Talk");
    const request = call.request;
    logger.info("======== [Unary RPC] ========");
    logger.info("Talk REQUEST: data=%s, meta=%s", request.getData(), request.getMeta());
    logger.info("Talk REQUEST TIME: %s", new Date().toISOString());

    // Extract and log headers
    const metadata = propagateHeaders("Talk", call);

    // Check if we should proxy to backend
    if (hasBackendClient()) {
        logger.info("Talk FORWARDING to next service");

        backendClient.talk(request, metadata, function (err, response) {
            if (err) {
                logger.error("Talk ERROR from backend: %s", err.message);
                // Propagate the backend's real gRPC status to the caller instead
                // of masking the failure with a fabricated local 200 response.
                callback(toGrpcError(err, ""), null);
            } else {
                logger.info("Talk RESPONSE from backend received");
                callback(null, response);
            }
        });
    } else {
        // Process locally
        handleLocalTalk(request, callback);
    }
}

/**
 * Local processing for unary RPC
 * @param {Object} request The gRPC request
 * @param {Function} callback Callback to return the response
 */
function handleLocalTalk(request, callback) {
    const response = new TalkResponse();
    response.setStatus(200);

    try {
        const talkResult = createResult(request.getData());
        const talkResults = [talkResult];
        response.setResultsList(talkResults);

        // Log the response details
        logger.info("Talk RESPONSE: status=%d, resultCount=%d", response.getStatus(), talkResults.length);
        const result = talkResults[0];
        const kv = result.getKvMap();
        logger.info("Talk RESPONSE DETAIL: id=%d, type=%s, data=%s",
            result.getId(),
            result.getType(),
            kv.get("data")
        );
    } catch (e) {
        logger.error("Error processing Talk request: %s", e.message);
        callback(e, null);
        return;
    }

    logger.info("Talk RESPONSE TIME: %s", new Date().toISOString());
    logger.info("============================");

    callback(null, response);
}

/**
 * Server Streaming RPC method implementation
 * @param {Object} call The gRPC call object
 */
function talkOneAnswerMore(call) {
    recordRpcCall("TalkOneAnswerMore");
    const request = call.request;
    logger.info("======== [Server Streaming RPC] ========");
    logger.info("TalkOneAnswerMore REQUEST: data=%s, meta=%s", request.getData(), request.getMeta());
    logger.info("TalkOneAnswerMore REQUEST TIME: %s", new Date().toISOString());

    // Extract and log headers
    const metadata = propagateHeaders("TalkOneAnswerMore", call);

    // Check if we should proxy to backend
    if (hasBackendClient()) {
        logger.info("TalkOneAnswerMore FORWARDING to next service");

        try {
            const nextCall = backendClient.talkOneAnswerMore(request, metadata);

            nextCall.on('data', function (response) {
                logger.info("TalkOneAnswerMore RESPONSE from next service received");
                call.write(response);
            });

            nextCall.on('end', function () {
                logger.info("TalkOneAnswerMore stream from next service END");
                logger.info("============================");
                call.end();
            });

            nextCall.on('error', function (error) {
                logger.error("TalkOneAnswerMore ERROR from next service: %s", error.message);
                // Propagate the backend's real gRPC status instead of masking
                // the failure with fabricated local responses.
                call.emit('error', toGrpcError(error, ""));
            });
        } catch (e) {
            logger.error("Failed to create backend call: %s", e.message);
            call.emit('error', toGrpcError(e, ""));
        }
    } else {
        // Process locally
        handleLocalTalkOneAnswerMore(request, call);
    }
}

/**
 * Local processing for server streaming RPC
 * @param {Object} request The gRPC request
 * @param {Object} call The gRPC call object
 */
function handleLocalTalkOneAnswerMore(request, call) {
    try {
        const datas = request.getData().split(",");
        logger.info("TalkOneAnswerMore processing %d items", datas.length);
        let responseCount = 0;

        for (const data of datas) {
            const response = new TalkResponse();
            response.setStatus(200);
            const talkResult = createResult(data);
            const talkResults = [talkResult];
            response.setResultsList(talkResults);

            // Log each response in the stream
            responseCount++;
            logger.info("TalkOneAnswerMore RESPONSE #%d: status=%d", responseCount, response.getStatus());
            const result = talkResults[0];
            const kv = result.getKvMap();
            logger.info("TalkOneAnswerMore RESPONSE #%d DETAIL: id=%d, type=%s, data=%s",
                responseCount,
                result.getId(),
                result.getType(),
                kv.get("data")
            );

            call.write(response);
        }

        logger.info("TalkOneAnswerMore sent %d responses", responseCount);
        logger.info("TalkOneAnswerMore COMPLETION TIME: %s", new Date().toISOString());
        logger.info("============================");
        call.end();
    } catch (e) {
        logger.error("Error processing TalkOneAnswerMore request: %s", e.message);
        call.emit('error', e);
    }
}

/**
 * Client Streaming RPC method implementation
 * @param {Object} call The gRPC call object
 * @param {Function} callback Callback to return the response
 */
function talkMoreAnswerOne(call, callback) {
    recordRpcCall("TalkMoreAnswerOne");
    logger.info("======== [Client Streaming RPC] ========");
    logger.info("TalkMoreAnswerOne STARTED at: %s", new Date().toISOString());

    // Extract and log headers
    const metadata = propagateHeaders("TalkMoreAnswerOne", call);
    let requestCount = 0;

    // Check if we should proxy to backend
    if (hasBackendClient()) {
        logger.info("TalkMoreAnswerOne FORWARDING to next service");

        try {
            const nextCall = backendClient.talkMoreAnswerOne(metadata, function (err, response) {
                if (err) {
                    logger.error("TalkMoreAnswerOne ERROR from backend: %s", err.message);
                    // Propagate the backend's real gRPC status instead of masking
                    // the failure with a fabricated local aggregate response.
                    callback(toGrpcError(err, ""), null);
                } else {
                    logger.info("TalkMoreAnswerOne RESPONSE from next service: status=%d, resultsCount=%d",
                        response.getStatus(),
                        response.getResultsList().length
                    );
                    logger.info("TalkMoreAnswerOne COMPLETION TIME: %s", new Date().toISOString());
                    logger.info("============================");
                    callback(null, response);
                }
            });

            call.on('data', function (request) {
                requestCount++;
                logger.info("TalkMoreAnswerOne REQUEST #%d: data=%s, meta=%s",
                    requestCount, request.getData(), request.getMeta());
                nextCall.write(request);
            });

            call.on('end', function () {
                logger.info("TalkMoreAnswerOne received %d requests in total", requestCount);
                nextCall.end();
            });

            call.on('error', function (e) {
                logger.error("TalkMoreAnswerOne CLIENT ERROR: %s", e.message);
                nextCall.end();
            });
        } catch (e) {
            logger.error("Failed to create backend call: %s", e.message);
            callback(toGrpcError(e, ""), null);
        }
    } else {
        // Process locally
        handleLocalTalkMoreAnswerOne(call, 0, callback);
    }
}

/**
 * Local processing for client streaming RPC
 * @param {Object} call The gRPC call object
 * @param {number} initialCount The initial count of requests processed
 * @param {Function} callback Callback to return the response
 */
function handleLocalTalkMoreAnswerOne(call, initialCount, callback) {
    const talkResults = [];
    let requestCount = initialCount;
    let terminalError = null;
    let completed = false;

    function finish(error, response) {
        if (completed) return;
        completed = true;
        callback(error, response);
    }

    call.on('data', function (request) {
        if (terminalError) return;
        requestCount++;
        logger.info("TalkMoreAnswerOne REQUEST #%d: data=%s, meta=%s",
            requestCount, request.getData(), request.getMeta());

        try {
            // Build result for this request
            const result = createResult(request.getData());
            talkResults.push(result);

            // Log the result details
            const kv = result.getKvMap();
            logger.info("TalkMoreAnswerOne PROCESSING REQUEST #%d: result id=%d, type=%s, data=%s",
                requestCount,
                result.getId(),
                result.getType(),
                kv.get("data")
            );
        } catch (e) {
            logger.error("Error processing request #%d: %s", requestCount, e.message);
            terminalError = e;
        }
    });

    call.on('end', function () {
        if (terminalError) {
            finish(terminalError, null);
            return;
        }
        const response = new TalkResponse();
        response.setStatus(200);
        response.setResultsList(talkResults);

        logger.info("TalkMoreAnswerOne received %d requests in total", requestCount);
        logger.info("TalkMoreAnswerOne RESPONSE: status=%d, resultsCount=%d",
            response.getStatus(),
            talkResults.length
        );

        // Log the first few results for clarity
        const logLimit = Math.min(talkResults.length, 3);
        for (let i = 0; i < logLimit; i++) {
            const result = talkResults[i];
            const kv = result.getKvMap();
            logger.info("TalkMoreAnswerOne RESPONSE DETAIL #%d: id=%d, type=%s, data=%s",
                i + 1,
                result.getId(),
                result.getType(),
                kv.get("data")
            );
        }

        if (talkResults.length > logLimit) {
            logger.info("TalkMoreAnswerOne (and %d more results...)", talkResults.length - logLimit);
        }

        logger.info("TalkMoreAnswerOne COMPLETION TIME: %s", new Date().toISOString());
        logger.info("============================");

        finish(null, response);
    });

    call.on('error', function (e) {
        logger.error("TalkMoreAnswerOne CLIENT ERROR: %s", e.message);
        finish(e, null);
    });
}

/**
 * Bidirectional Streaming RPC method implementation
 * @param {Object} call The gRPC call object
 */
function talkBidirectional(call) {
    recordRpcCall("TalkBidirectional");
    logger.info("======== [Bidirectional Streaming RPC] ========");
    logger.info("TalkBidirectional STARTED at: %s", new Date().toISOString());

    // Extract and log headers
    const metadata = propagateHeaders("TalkBidirectional", call);
    let requestCount = 0;
    let responseCount = 0;

    // Check if we should proxy to backend
    if (hasBackendClient()) {
        logger.info("TalkBidirectional FORWARDING to next service");

        try {
            const nextCall = backendClient.talkBidirectional(metadata);

            nextCall.on('data', function (response) {
                responseCount++;
                logger.info("TalkBidirectional RESPONSE #%d from next service received", responseCount);
                call.write(response);
            });

            nextCall.on('end', function () {
                logger.info("TalkBidirectional stream from next service END");
                logger.info("TalkBidirectional sent %d responses in total", responseCount);
                logger.info("TalkBidirectional COMPLETION TIME: %s", new Date().toISOString());
                logger.info("============================");
                call.end();
            });

            nextCall.on('error', function (error) {
                logger.error("TalkBidirectional ERROR from next service: %s", error.message);
                // Propagate the backend's real gRPC status instead of masking
                // the failure with fabricated local responses.
                call.emit('error', toGrpcError(error, ""));
            });

            call.on('data', function (request) {
                requestCount++;
                logger.info("TalkBidirectional REQUEST #%d: data=%s, meta=%s",
                    requestCount, request.getData(), request.getMeta());
                nextCall.write(request);
            });

            call.on('end', function () {
                logger.info("TalkBidirectional received %d requests in total", requestCount);
                nextCall.end();
            });

            call.on('error', function (error) {
                logger.error("TalkBidirectional CLIENT ERROR: %s", error.message);
                nextCall.end();
            });
        } catch (e) {
            logger.error("Failed to create backend call: %s", e.message);
            call.emit('error', toGrpcError(e, ""));
        }
    } else {
        // Process locally
        handleLocalTalkBidirectional(call, 0);
    }
}

/**
 * Local processing for bidirectional streaming RPC
 * @param {Object} call The gRPC call object
 * @param {number} initialCount The initial count of requests processed
 */
function handleLocalTalkBidirectional(call, initialCount) {
    let requestCount = initialCount;
    let responseCount = 0;
    let failed = false;

    call.on('data', function (request) {
        if (failed) return;
        requestCount++;
        logger.info("TalkBidirectional REQUEST #%d: data=%s, meta=%s",
            requestCount, request.getData(), request.getMeta());

        try {
            // Create response for this request
            const response = new TalkResponse();
            response.setStatus(200);
            const data = request.getData();
            const talkResult = createResult(data);
            const talkResults = [talkResult];
            response.setResultsList(talkResults);

            // Log the response details
            responseCount++;
            const kv = talkResult.getKvMap();
            logger.info("TalkBidirectional RESPONSE #%d: status=%d", responseCount, response.getStatus());
            logger.info("TalkBidirectional RESPONSE #%d DETAIL: id=%d, type=%s, data=%s",
                responseCount,
                talkResult.getId(),
                talkResult.getType(),
                kv.get("data")
            );

            // Send the response
            call.write(response);
        } catch (e) {
            logger.error("Error processing request #%d: %s", requestCount, e.message);
            failed = true;
            call.emit('error', e);
        }
    });

    call.on('end', function () {
        logger.info("TalkBidirectional received %d requests and sent %d responses",
            requestCount, responseCount);
        logger.info("TalkBidirectional COMPLETION TIME: %s", new Date().toISOString());
        logger.info("============================");
        if (!failed) call.end();
    });

    call.on('error', function (error) {
        logger.error("TalkBidirectional CLIENT ERROR: %s", error.message);
        call.end();
    });
}

/**
 * Check if a backend service is configured
 * @returns {boolean} True if backend is configured
 */
function hasBackend() {
    const backend = process.env.GRPC_HELLO_BACKEND;
    return typeof backend !== 'undefined' && backend !== null;
}

/**
 * Check if the backend client is available
 * @returns {boolean} True if backend client is available
 */
function hasBackendClient() {
    return backendClient !== null;
}

/**
 * Create a response result with the appropriate data
 * @param {string} id The request ID (typically a language index)
 * @returns {TalkResult} The generated result
 */
function createResult(id) {
    const result = new TalkResult();

    const index = parseDataIndex(id, utils.hellos.length);

    const hello = utils.hellos[index];

    result.setId(Math.round(Date.now() / 1000));
    result.setType(ResultType.OK);
    const kv = result.getKvMap();
    kv.set("id", uuid.v4());
    kv.set("idx", id);
    kv.set("data", hello + "," + utils.ans().get(hello));
    kv.set("meta", "NODEJS");

    return result;
}

/**
 * Extract and log headers, return those that should be propagated
 * @param {string} methodName The name of the RPC method
 * @param {Object} call The gRPC call object
 * @returns {grpc.Metadata} Metadata to propagate to backend service
 */
function propagateHeaders(methodName, call) {
    const headers = call.metadata.getMap();
    const metadata = new grpc.Metadata();

    // Log all headers
    if (Object.keys(headers).length === 0) {
        logger.info("%s - No metadata present", methodName);
    } else {
        for (const key in headers) {
            logger.info("%s HEADER: %s:%s", methodName, key, headers[key]);

            // Propagate tracing headers to backend
            if (tracingHeaders.includes(key)) {
                metadata.add(key, headers[key]);
            }
        }
    }

    return metadata;
}

// Start the server
main().catch(err => {
    logger.error("Failed to start server: %s", err.message);
    process.exit(1);
});
