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

const grpc = require('@grpc/grpc-js');
const uuid = require('uuid');
const { TalkResult, TalkResponse, ResultType } = require('./common/landing_pb');
const services = require('./common/landing_grpc_pb');
const conn = require('./common/connection');
const utils = require('./common/utils');
// Server reflection can be enabled if needed
// const reflection = require('grpc-node-server-reflection');

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
const cert = path.join(certBasePath, "cert.pem");
const certKey = path.join(certBasePath, "private.key");
const certChain = path.join(certBasePath, "full_chain.pem");
const rootCert = path.join(certBasePath, "myssl_root.cer");

/**
 * Starts an RPC server that receives requests for the LandingService
 */
function main() {
    logger.info("Starting gRPC server with Node.js implementation");

    // Initialize backend client if configured
    if (hasBackend()) {
        backendClient = conn.getClient();
        logger.info("Backend client initialized for proxying requests");
    }

    // Get server port from environment variable or use default
    const port = process.env.GRPC_SERVER_PORT || "9996";
    const address = "0.0.0.0:" + port;

    // Create new gRPC server
    const server = new grpc.Server();

    // Add service implementation
    server.addService(services.LandingServiceService, {
        talk: talk,
        talkOneAnswerMore: talkOneAnswerMore,
        talkMoreAnswerOne: talkMoreAnswerOne,
        talkBidirectional: talkBidirectional
    });

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
        if (!fs.existsSync(cert)) {
            logger.error(`Certificate file not found: ${cert}`);
            throw new Error(`Certificate file not found: ${cert}`);
        }

        if (!fs.existsSync(certKey)) {
            logger.error(`Private key file not found: ${certKey}`);
            throw new Error(`Private key file not found: ${certKey}`);
        }

        // Read certificates
        const certContent = fs.readFileSync(cert);
        const privateKeyContent = fs.readFileSync(certKey);

        // Check for root certificate (optional)
        let rootCertContent = null;
        if (fs.existsSync(rootCert)) {
            rootCertContent = fs.readFileSync(rootCert);
            logger.info("Using root certificate for client verification");
        } else {
            logger.info("Root certificate not found, client verification disabled");
        }

        // Create TLS credentials - don't require client certificates (false)
        const credentials = grpc.ServerCredentials.createSsl(
            rootCertContent,  // Root certificates (can be null)
            [{
                cert_chain: certContent,
                private_key: privateKeyContent
            }],
            false // Don't require client certificate
        );

        server.bindAsync(address, credentials, (err, port) => {
            if (err) {
                logger.error("Failed to bind TLS server:", err);
                logger.info("Falling back to insecure server");
                startInsecureServer(server, address);
            } else {
                server.start();
                logger.info("Start GRPC TLS Server on port %s [%s]", port, utils.getVersion());
            }
        });
    } catch (err) {
        logger.error("Failed to start TLS server:", err);
        logger.info("Falling back to insecure server");
        startInsecureServer(server, address);
    }
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
        server.start();
        logger.info("Start GRPC Server on port %s [%s]", port, utils.getVersion());
    });
}

/**
 * Unary RPC method implementation
 * @param {Object} call The gRPC call object
 * @param {Function} callback Callback to return the response
 */
function talk(call, callback) {
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
                // Fall back to local processing
                handleLocalTalk(request, callback);
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
        response.setStatus(500);
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
                // Fall back to local processing
                handleLocalTalkOneAnswerMore(request, call);
            });
        } catch (e) {
            logger.error("Failed to create backend call: %s", e.message);
            // Fall back to local processing
            handleLocalTalkOneAnswerMore(request, call);
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
    } catch (e) {
        logger.error("Error processing TalkOneAnswerMore request: %s", e.message);
    } finally {
        call.end();
    }
}

/**
 * Client Streaming RPC method implementation
 * @param {Object} call The gRPC call object
 * @param {Function} callback Callback to return the response
 */
function talkMoreAnswerOne(call, callback) {
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
                    // Fall back to local processing
                    handleLocalTalkMoreAnswerOne(call, requestCount, callback);
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
            // Fall back to local processing
            handleLocalTalkMoreAnswerOne(call, 0, callback);
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

    call.on('data', function (request) {
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
        }
    });

    call.on('end', function () {
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

        callback(null, response);
    });

    call.on('error', function (e) {
        logger.error("TalkMoreAnswerOne CLIENT ERROR: %s", e.message);
        // Return an empty response in case of error
        const response = new TalkResponse();
        response.setStatus(500);
        response.setResultsList([]);
        callback(null, response);
    });
}

/**
 * Bidirectional Streaming RPC method implementation
 * @param {Object} call The gRPC call object
 */
function talkBidirectional(call) {
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
                // Fall back to local processing
                handleLocalTalkBidirectional(call, requestCount);
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
            // Fall back to local processing
            handleLocalTalkBidirectional(call, 0);
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

    call.on('data', function (request) {
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
        }
    });

    call.on('end', function () {
        logger.info("TalkBidirectional received %d requests and sent %d responses",
            requestCount, responseCount);
        logger.info("TalkBidirectional COMPLETION TIME: %s", new Date().toISOString());
        logger.info("============================");
        call.end();
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

    // Parse ID safely
    let index;
    try {
        index = parseInt(id);

        // Check for out-of-bounds index
        if (isNaN(index) || index < 0 || index >= utils.hellos.length) {
            index = 0;
        }
    } catch (e) {
        index = 0;
    }

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
main();