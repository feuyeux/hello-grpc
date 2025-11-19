import * as grpc from '@grpc/grpc-js'
import { sendUnaryData } from '@grpc/grpc-js/build/src/server-call'
import { ILandingServiceServer, LandingServiceService } from "./generated/landing_grpc_pb"
import { ResultType, TalkRequest, TalkResponse, TalkResult } from "./generated/landing_pb"
import { v4 as uuidv4 } from "uuid"
import { ans, getVersion, hellos } from "./lib/utils"
import { createClient, getServerPort, logger } from "./lib/conn"
import { createServerCredentials, testTlsCertificates } from "./lib/tls"

import * as fs from 'fs'
import * as path from 'path'
import * as os from 'os'

// Headers to propagate for distributed tracing
const TRACING_HEADERS = [
    "x-request-id",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-ot-span-context"
]

/**
 * Get certificate base path based on the operating system or environment variables.
 * Checks in the following order:
 * 1. CERT_BASE_PATH environment variable
 * 2. Local 'certs/server_certs' directory
 * 3. OS-specific default paths
 * 
 * @returns {string} Path to certificate directory
 */
function getCertBasePath(): string {
    // First check for environment variable
    if (process.env.CERT_BASE_PATH) {
        return process.env.CERT_BASE_PATH;
    }

    // Then try local path
    const localCertPath = path.join(__dirname, 'certs', 'server_certs');
    if (fs.existsSync(localCertPath)) {
        return localCertPath;
    }

    // Finally use OS-specific default paths
    const platform = os.platform()

    switch (platform) {
        case 'win32':
            return "d:\\garden\\var\\hello_grpc\\server_certs"
        case 'darwin':
            return "/var/hello_grpc/server_certs"
        default:
            return "/var/hello_grpc/server_certs"
    }
}

// Certificate paths
const certBasePath = getCertBasePath()
const certPath = path.join(certBasePath, "cert.pem")
const certKeyPath = path.join(certBasePath, "private.key")
const certChainPath = path.join(certBasePath, "full_chain.pem")
const rootCertPath = path.join(certBasePath, "myssl_root.cer")

/**
 * Creates a response result object with the appropriate data
 * 
 * @param {string} data - The request index/data
 * @returns {TalkResult} Result object with formatted data
 */
function createResponse(data: string): TalkResult {
    const result = new TalkResult()

    // Parse the input as an index
    const index = parseInt(data, 10)

    // Handle potential non-numeric or out-of-bounds indices
    const safeIndex = isNaN(index) || index < 0 || index >= hellos.length
        ? 0
        : index

    const hello = hellos[safeIndex]
    const answer = ans.get(hello)

    // Set basic properties
    result.setId(Math.round(Date.now() / 1000))
    result.setType(ResultType.OK)

    // Add key-value metadata
    const kv = result.getKvMap()
    kv.set("id", uuidv4())
    kv.set("idx", data)
    kv.set("data", `${hello},${answer}`)
    kv.set("meta", "TypeScript")

    return result
}

/**
 * Prepares metadata for forwarding to backend services
 * 
 * @param {grpc.Metadata} originalMetadata - Original client metadata
 * @returns {grpc.Metadata} Prepared metadata for backend requests
 */
function prepareMetadata(originalMetadata: grpc.Metadata): grpc.Metadata {
    const backendMetadata = new grpc.Metadata()

    // Copy all tracing headers to backend
    const metadataMap = originalMetadata.getMap()
    for (const key of TRACING_HEADERS) {
        if (metadataMap[key]) {
            backendMetadata.set(key, metadataMap[key])
        }
    }

    // Add proxy information
    backendMetadata.set('x-proxy-by', 'typescript-server')
    backendMetadata.set('x-proxy-timestamp', Date.now().toString())

    return backendMetadata
}

/**
 * Extracts and logs tracing headers from request metadata
 * 
 * @param {string} methodName - The name of the RPC method
 * @param {Object} headers - Headers from the request
 * @returns {grpc.Metadata} Metadata containing only tracing headers
 */
function extractTracingHeaders(methodName: string, headers: { [key: string]: grpc.MetadataValue }): grpc.Metadata {
    const metadata = new grpc.Metadata()

    // Log all headers
    if (Object.keys(headers).length === 0) {
        logger.info("%s - No headers present", methodName)
    } else {
        for (const key in headers) {
            const value = headers[key]
            logger.info("%s HEADER: %s:%s", methodName, key, value)

            // Collect tracing headers
            if (TRACING_HEADERS.includes(key)) {
                metadata.add(key, value)
            }
        }
    }

    return metadata
}

/**
 * Implementation of the Landing Service
 * Handles all RPC methods defined in the proto file
 */
class HelloServer implements ILandingServiceServer {
    // Define the index signature to only include public methods that should be gRPC handlers
    [key: string]: any;

    private backendClient: any = null;

    constructor() {
        // Check if we should operate in proxy mode
        if (this.hasBackend()) {
            logger.info("Starting server in proxy mode")
            try {
                this.backendClient = createClient()
                logger.info("Created backend client for proxying requests")
            } catch (error) {
                logger.error("Failed to create backend client: %s",
                    error instanceof Error ? error.message : String(error))
                logger.info("Server will operate in non-proxy mode despite backend configuration")
            }
        } else {
            logger.info("Starting server in standalone mode")
        }
    }

    /**
     * Checks if a backend service is configured
     * 
     * @returns {boolean} True if backend is configured, false otherwise
     */
    private hasBackend(): boolean {
        const backend = process.env.GRPC_HELLO_BACKEND
        return typeof backend !== 'undefined' && backend !== null
    }

    /**
     * Checks if backend client is available for proxying
     * 
     * @returns {boolean} True if backend client is available
     */
    private hasBackendClient(): boolean {
        return this.backendClient !== null
    }

    /**
     * Implements the Talk unary RPC method
     */
    talk(call: grpc.ServerUnaryCall<TalkRequest, TalkResponse>, callback: sendUnaryData<TalkResponse>): void {
        const request = call.request
        const data = request.getData()
        const meta = request.getMeta()

        logger.info("======== [Unary RPC] ========")
        logger.info("Talk REQUEST: data=%s, meta=%s", data, meta)
        logger.info("Talk REQUEST TIME: %s", new Date().toISOString())

        // Extract tracing headers
        const metadata = extractTracingHeaders("Talk", call.metadata.getMap())

        // If in proxy mode, forward request to backend
        if (this.hasBackendClient()) {
            logger.info("Talk FORWARDING to next service")
            const backendMetadata = prepareMetadata(call.metadata)

            this.backendClient.talk(request, backendMetadata, (err: Error, response: TalkResponse) => {
                if (err) {
                    logger.error("Talk ERROR from backend: %s", err.message)
                    // Fall back to local processing
                    this.handleLocalTalk(request, callback)
                } else {
                    logger.info("Talk RESPONSE from backend received")
                    logger.info("Talk RESPONSE TIME: %s", new Date().toISOString())
                    logger.info("============================")
                    callback(null, response)
                }
            })
        } else {
            // Process locally
            this.handleLocalTalk(request, callback)
        }
    }

    /**
     * Handle local processing for unary RPC
     * 
     * @param {TalkRequest} request The gRPC request
     * @param {sendUnaryData<TalkResponse>} callback Callback to return response
     */
    private handleLocalTalk(request: TalkRequest, callback: sendUnaryData<TalkResponse>): void {
        try {
            const response = new TalkResponse()
            response.setStatus(200)

            const result = createResponse(request.getData())
            response.setResultsList([result])

            // Log response details
            logger.info("Talk RESPONSE: status=%d, resultCount=1", response.getStatus())
            const resultKv = result.getKvMap()
            logger.info("Talk RESPONSE DETAIL: id=%d, type=%s, data=%s",
                result.getId(),
                result.getType(),
                resultKv.get("data")
            )

            logger.info("Talk RESPONSE TIME: %s", new Date().toISOString())
            logger.info("============================")

            callback(null, response)
        } catch (error) {
            logger.error("Error processing Talk request: %s",
                error instanceof Error ? error.message : String(error))

            const response = new TalkResponse()
            response.setStatus(500)
            response.setResultsList([])

            logger.info("Talk ERROR RESPONSE TIME: %s", new Date().toISOString())
            logger.info("============================")

            callback(null, response)
        }
    }

    /**
     * Implements the TalkMoreAnswerOne client streaming RPC method
     */
    talkMoreAnswerOne(call: grpc.ServerReadableStream<TalkRequest, TalkResponse>, callback: sendUnaryData<TalkResponse>): void {
        logger.info("======== [Client Streaming RPC] ========")
        logger.info("TalkMoreAnswerOne STARTED at: %s", new Date().toISOString())

        // Extract tracing headers
        const metadata = extractTracingHeaders("TalkMoreAnswerOne", call.metadata.getMap())

        let requestCount = 0

        // If in proxy mode, forward request to backend
        if (this.hasBackendClient()) {
            logger.info("TalkMoreAnswerOne FORWARDING to next service")
            const backendMetadata = prepareMetadata(call.metadata)

            try {
                // Get backend stream
                const backendStream = this.backendClient.talkMoreAnswerOne(backendMetadata, (err: grpc.ServiceError | null, response: TalkResponse) => {
                    if (err) {
                        logger.error("TalkMoreAnswerOne ERROR from backend: %s", err.message)
                        // Fall back to local processing
                        this.handleLocalTalkMoreAnswerOne(call, requestCount, callback)
                    } else {
                        logger.info("TalkMoreAnswerOne RESPONSE from backend: status=%d, resultsCount=%d",
                            response.getStatus(),
                            response.getResultsList().length
                        )
                        logger.info("TalkMoreAnswerOne COMPLETION TIME: %s", new Date().toISOString())
                        logger.info("============================")
                        callback(null, response)
                    }
                })

                // Forward client requests to backend
                call.on('data', (request: TalkRequest) => {
                    requestCount++
                    logger.info("TalkMoreAnswerOne REQUEST #%d: data=%s, meta=%s",
                        requestCount, request.getData(), request.getMeta())
                    backendStream.write(request)
                })

                call.on('end', () => {
                    logger.info("TalkMoreAnswerOne received %d requests in total", requestCount)
                    backendStream.end()
                })

                call.on('error', (e: Error) => {
                    logger.error("TalkMoreAnswerOne CLIENT ERROR: %s", e.message)
                    backendStream.end()
                })
            } catch (error) {
                logger.error("Failed to create backend stream: %s",
                    error instanceof Error ? error.message : String(error))
                // Fall back to local processing
                this.handleLocalTalkMoreAnswerOne(call, 0, callback)
            }
        } else {
            // Process locally
            this.handleLocalTalkMoreAnswerOne(call, 0, callback)
        }
    }

    /**
     * Handle local processing for client streaming RPC
     * 
     * @param {grpc.ServerReadableStream<TalkRequest, TalkResponse>} call The streaming call
     * @param {number} initialCount Initial count of requests already processed
     * @param {sendUnaryData<TalkResponse>} callback Callback to return response
     */
    private handleLocalTalkMoreAnswerOne(
        call: grpc.ServerReadableStream<TalkRequest, TalkResponse>,
        initialCount: number,
        callback: sendUnaryData<TalkResponse>
    ): void {
        const talkResults: TalkResult[] = []
        let requestCount = initialCount

        call.on('data', (request: TalkRequest) => {
            requestCount++
            logger.info("TalkMoreAnswerOne REQUEST #%d: data=%s, meta=%s",
                requestCount, request.getData(), request.getMeta())

            try {
                // Build result for this request
                const result = createResponse(request.getData())
                talkResults.push(result)

                // Log the result details
                const kv = result.getKvMap()
                logger.info("TalkMoreAnswerOne PROCESSING REQUEST #%d: result id=%d, type=%s, data=%s",
                    requestCount,
                    result.getId(),
                    result.getType(),
                    kv.get("data")
                )
            } catch (error) {
                logger.error("Error processing request #%d: %s", requestCount,
                    error instanceof Error ? error.message : String(error))
            }
        })

        call.on('end', () => {
            const response = new TalkResponse()
            response.setStatus(200)
            response.setResultsList(talkResults)

            logger.info("TalkMoreAnswerOne received %d requests in total", requestCount)
            logger.info("TalkMoreAnswerOne RESPONSE: status=%d, resultsCount=%d",
                response.getStatus(),
                talkResults.length
            )

            // Log the first few results for clarity
            const logLimit = Math.min(talkResults.length, 3)
            for (let i = 0; i < logLimit; i++) {
                const result = talkResults[i]
                const kv = result.getKvMap()
                logger.info("TalkMoreAnswerOne RESPONSE DETAIL #%d: id=%d, type=%s, data=%s",
                    i + 1,
                    result.getId(),
                    result.getType(),
                    kv.get("data")
                )
            }

            if (talkResults.length > logLimit) {
                logger.info("TalkMoreAnswerOne (and %d more results...)", talkResults.length - logLimit)
            }

            logger.info("TalkMoreAnswerOne COMPLETION TIME: %s", new Date().toISOString())
            logger.info("============================")

            callback(null, response)
        })

        call.on('error', (e: Error) => {
            logger.error("TalkMoreAnswerOne CLIENT ERROR: %s", e.message)
            // Return an empty response in case of error
            const response = new TalkResponse()
            response.setStatus(500)
            response.setResultsList([])
            callback(null, response)
        })
    }

    /**
     * Implements the TalkOneAnswerMore server streaming RPC method
     */
    talkOneAnswerMore(call: grpc.ServerWritableStream<TalkRequest, TalkResponse>): void {
        const request = call.request
        const data = request.getData()
        const meta = request.getMeta()

        logger.info("======== [Server Streaming RPC] ========")
        logger.info("TalkOneAnswerMore REQUEST: data=%s, meta=%s", data, meta)
        logger.info("TalkOneAnswerMore REQUEST TIME: %s", new Date().toISOString())

        // Extract tracing headers
        const metadata = extractTracingHeaders("TalkOneAnswerMore", call.metadata.getMap())

        // If in proxy mode, forward request to backend
        if (this.hasBackendClient()) {
            logger.info("TalkOneAnswerMore FORWARDING to next service")
            const backendMetadata = prepareMetadata(call.metadata)

            try {
                // Get backend stream
                const backendStream = this.backendClient.talkOneAnswerMore(request, backendMetadata)

                // Forward backend responses to client
                backendStream.on('data', (response: TalkResponse) => {
                    logger.info("TalkOneAnswerMore RESPONSE from next service received")
                    call.write(response)
                })

                backendStream.on('end', () => {
                    logger.info("TalkOneAnswerMore stream from next service END")
                    logger.info("TalkOneAnswerMore COMPLETION TIME: %s", new Date().toISOString())
                    logger.info("============================")
                    call.end()
                })

                backendStream.on('error', (err: Error) => {
                    logger.error("TalkOneAnswerMore ERROR from next service: %s", err.message)
                    // Fall back to local processing
                    this.handleLocalTalkOneAnswerMore(request, call)
                })
            } catch (error) {
                logger.error("Failed to create backend stream: %s",
                    error instanceof Error ? error.message : String(error))
                // Fall back to local processing
                this.handleLocalTalkOneAnswerMore(request, call)
            }
        } else {
            // Process locally
            this.handleLocalTalkOneAnswerMore(request, call)
        }
    }

    /**
     * Handle local processing for server streaming RPC
     * 
     * @param {TalkRequest} request The gRPC request
     * @param {grpc.ServerWritableStream<TalkRequest, TalkResponse>} call The streaming call
     */
    private handleLocalTalkOneAnswerMore(
        request: TalkRequest,
        call: grpc.ServerWritableStream<TalkRequest, TalkResponse>
    ): void {
        try {
            const dataItems = request.getData().split(",")
            logger.info("TalkOneAnswerMore processing %d items", dataItems.length)
            let responseCount = 0

            for (const dataItem of dataItems) {
                const response = new TalkResponse()
                response.setStatus(200)
                const result = createResponse(dataItem)
                response.setResultsList([result])

                // Log each response in the stream
                responseCount++
                logger.info("TalkOneAnswerMore RESPONSE #%d: status=%d", responseCount, response.getStatus())
                const kv = result.getKvMap()
                logger.info("TalkOneAnswerMore RESPONSE #%d DETAIL: id=%d, type=%s, data=%s",
                    responseCount,
                    result.getId(),
                    result.getType(),
                    kv.get("data")
                )

                call.write(response)
            }

            logger.info("TalkOneAnswerMore sent %d responses", responseCount)
            logger.info("TalkOneAnswerMore COMPLETION TIME: %s", new Date().toISOString())
            logger.info("============================")
        } catch (error) {
            logger.error("Error processing TalkOneAnswerMore request: %s",
                error instanceof Error ? error.message : String(error))
        } finally {
            call.end()
        }
    }

    /**
     * Implements the TalkBidirectional bidirectional streaming RPC method
     */
    talkBidirectional(call: grpc.ServerDuplexStream<TalkRequest, TalkResponse>): void {
        logger.info("======== [Bidirectional Streaming RPC] ========")
        logger.info("TalkBidirectional STARTED at: %s", new Date().toISOString())

        // Extract tracing headers
        const metadata = extractTracingHeaders("TalkBidirectional", call.metadata.getMap())
        let requestCount = 0
        let responseCount = 0

        // If in proxy mode, forward request to backend
        if (this.hasBackendClient()) {
            logger.info("TalkBidirectional FORWARDING to next service")
            const backendMetadata = prepareMetadata(call.metadata)

            try {
                // Get backend stream
                const backendStream = this.backendClient.talkBidirectional(backendMetadata)

                // Forward backend responses to client
                backendStream.on('data', (response: TalkResponse) => {
                    responseCount++
                    logger.info("TalkBidirectional RESPONSE #%d from next service received", responseCount)
                    call.write(response)
                })

                backendStream.on('end', () => {
                    logger.info("TalkBidirectional stream from next service END")
                    logger.info("TalkBidirectional sent %d responses in total", responseCount)
                    logger.info("TalkBidirectional COMPLETION TIME: %s", new Date().toISOString())
                    logger.info("============================")
                    call.end()
                })

                backendStream.on('error', (error: Error) => {
                    logger.error("TalkBidirectional ERROR from next service: %s", error.message)
                    // Fall back to local processing if backend fails
                    this.handleLocalTalkBidirectional(call, requestCount)
                })

                // Forward client requests to backend
                call.on('data', (request: TalkRequest) => {
                    requestCount++
                    logger.info("TalkBidirectional REQUEST #%d: data=%s, meta=%s",
                        requestCount, request.getData(), request.getMeta())
                    backendStream.write(request)
                })

                call.on('end', () => {
                    logger.info("TalkBidirectional received %d requests in total", requestCount)
                    backendStream.end()
                })

                call.on('error', (error: Error) => {
                    logger.error("TalkBidirectional CLIENT ERROR: %s", error.message)
                    backendStream.end()
                })
            } catch (error) {
                logger.error("Failed to create backend stream: %s",
                    error instanceof Error ? error.message : String(error))
                // Fall back to local processing
                this.handleLocalTalkBidirectional(call, 0)
            }
        } else {
            // Process locally
            this.handleLocalTalkBidirectional(call, 0)
        }
    }

    /**
     * Handle local processing for bidirectional streaming RPC
     * 
     * @param {grpc.ServerDuplexStream<TalkRequest, TalkResponse>} call The streaming call
     * @param {number} initialCount Initial count of requests already processed
     */
    private handleLocalTalkBidirectional(
        call: grpc.ServerDuplexStream<TalkRequest, TalkResponse>,
        initialCount: number
    ): void {
        let requestCount = initialCount
        let responseCount = 0

        call.on('data', (request: TalkRequest) => {
            requestCount++
            logger.info("TalkBidirectional REQUEST #%d: data=%s, meta=%s",
                requestCount, request.getData(), request.getMeta())

            try {
                // Create response for this request
                const response = new TalkResponse()
                response.setStatus(200)
                const result = createResponse(request.getData())
                response.setResultsList([result])

                // Log the response details
                responseCount++
                const kv = result.getKvMap()
                logger.info("TalkBidirectional RESPONSE #%d: status=%d", responseCount, response.getStatus())
                logger.info("TalkBidirectional RESPONSE #%d DETAIL: id=%d, type=%s, data=%s",
                    responseCount,
                    result.getId(),
                    result.getType(),
                    kv.get("data")
                )

                // Send the response
                call.write(response)
            } catch (error) {
                logger.error("Error processing request #%d: %s", requestCount,
                    error instanceof Error ? error.message : String(error))
            }
        })

        call.on('end', () => {
            logger.info("TalkBidirectional received %d requests and sent %d responses",
                requestCount, responseCount)
            logger.info("TalkBidirectional COMPLETION TIME: %s", new Date().toISOString())
            logger.info("============================")
            call.end()
        })

        call.on('error', (error: Error) => {
            logger.error("TalkBidirectional CLIENT ERROR: %s", error.message)
            call.end()
        })
    }
}

/**
 * Starts the gRPC server.
 * Attempts to start with TLS if configured, falls back to insecure if TLS fails.
 */
function startServer(): void {
    try {
        const server = new grpc.Server()
        server.addService(LandingServiceService, new HelloServer())

        // Get the port for the server
        const serverPort = getServerPort();
        const serverAddress = "0.0.0.0:" + serverPort

        // Set up signal handlers for graceful shutdown
        setupSignalHandlers(server);

        // Check if TLS is enabled via environment variable
        const secure = process.env.GRPC_HELLO_SECURE
        if (secure === "Y") {
            startSecureServer(server, serverAddress)
        } else {
            startInsecureServer(server, serverAddress)
        }
    } catch (error: unknown) {
        logger.error("Fatal error starting server: %s",
            error instanceof Error ? error.message : String(error))
        console.error("Fatal server error:", error)
        process.exit(1)
    }
}

/**
 * Starts the server with TLS security
 * Falls back to insecure server if TLS setup fails
 * 
 * @param {grpc.Server} server - The gRPC server instance
 * @param {string} serverAddress - The address:port to bind to
 */
function startSecureServer(server: grpc.Server, serverAddress: string): void {
    try {
        // Test TLS certificates before creating credentials
        if (!testTlsCertificates(true)) {
            throw new Error("TLS certificate test failed");
        }

        // Create TLS credentials
        const credentials = createServerCredentials();
        logger.info("TLS credentials created successfully");

        // Bind server with TLS
        logger.info("Starting gRPC TLS server on %s", serverAddress)

        server.bindAsync(
            serverAddress,
            credentials,
            (error: Error | null, bindPort: number) => {
                if (error) {
                    logger.error("Failed to start TLS server on port %s: %s", bindPort, error.message)
                    // If TLS binding fails, fall back to insecure mode
                    startInsecureServer(server, serverAddress)
                } else {
                    logger.info("TLS server started on port %s [version: %s]", bindPort, getVersion())
                }
            }
        )
    } catch (error: unknown) {
        logger.error("TLS setup failed: %s. Falling back to insecure.",
            error instanceof Error ? error.message : String(error))
        startInsecureServer(server, serverAddress)
    }
}

/**
 * Starts the server in insecure mode (without TLS)
 * 
 * @param {grpc.Server} server - The gRPC server instance
 * @param {string} serverAddress - The address:port to bind to
 */
function startInsecureServer(server: grpc.Server, serverAddress: string): void {
    logger.info("Starting insecure gRPC server on %s", serverAddress)

    server.bindAsync(
        serverAddress,
        grpc.ServerCredentials.createInsecure(),
        (error: Error | null, port: number) => {
            if (error) {
                logger.error("Failed to start insecure server on port %s: %s", port, error.message)
                process.exit(1)
            } else {
                logger.info("Insecure server started on port %s [version: %s]", port, getVersion())
            }
        }
    )
}

/**
 * Set up signal handlers for graceful shutdown
 * 
 * @param {grpc.Server} server - The gRPC server instance
 */
function setupSignalHandlers(server: grpc.Server): void {
    // Handle SIGINT (Ctrl+C)
    process.on('SIGINT', () => {
        logger.info("Received SIGINT signal, shutting down server...")
        gracefulShutdown(server)
    })

    // Handle SIGTERM
    process.on('SIGTERM', () => {
        logger.info("Received SIGTERM signal, shutting down server...")
        gracefulShutdown(server)
    })
}

/**
 * Gracefully shut down the server
 * 
 * @param {grpc.Server} server - The gRPC server instance
 */
function gracefulShutdown(server: grpc.Server): void {
    logger.info("Starting graceful shutdown...")

    // Try graceful shutdown with timeout
    const forceShutdownTimeout = setTimeout(() => {
        logger.warn("Graceful shutdown timed out, forcing exit")
        process.exit(1)
    }, 10000) // 10 seconds timeout

    server.tryShutdown(() => {
        clearTimeout(forceShutdownTimeout)
        logger.info("Server shutdown complete")
        process.exit(0)
    })
}

// Set up global error handlers
process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception: %s', error.message)
    console.error('Uncaught Exception:', error)
    process.exit(1)
})

process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Promise Rejection: %s', reason)
    console.error('Unhandled Promise Rejection:', reason)
    process.exit(1)
})

// Start the server
startServer()