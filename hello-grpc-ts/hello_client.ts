import * as grpc from '@grpc/grpc-js'
import { TalkRequest, TalkResponse } from "./common/landing_pb"
import { logger } from "./common/conn"
import { buildLinkRequests, getVersion, randomId } from "./common/utils"
import { LandingServiceClient } from './common/landing_grpc_pb'
import { createClientCredentials } from './common/tls'

// Configuration constants
const DEFAULT_TIMEOUT_MS = 10000
const DEFAULT_SERVER_HOST = 'localhost'
const DEFAULT_SERVER_PORT = '9996'

// Client instance initialized later
let client: LandingServiceClient

/**
 * Executes a unary RPC call to the server
 * 
 * @param {TalkRequest} request - Request payload
 * @returns {Promise<TalkResponse>} Response from the server
 */
function talk(request: TalkRequest): Promise<TalkResponse> {
    logger.info("======== [Unary RPC] ========")
    logger.info("Talk REQUEST: data=%s, meta=%s", request.getData(), request.getMeta())
    logger.info("Talk REQUEST TIME: %s", new Date().toISOString())

    return new Promise<TalkResponse>((resolve, reject) => {
        try {
            // Create metadata with request ID for tracing
            const metadata = new grpc.Metadata()
            metadata.add("request-id", `unary-${Date.now()}`)

            // Set deadline for the request
            const deadline = new Date(Date.now() + DEFAULT_TIMEOUT_MS)
            const options = { deadline }

            client.talk(request, metadata, options, (err: Error | null, response: TalkResponse) => {
                if (err) {
                    logger.error("Talk ERROR: %s, code: %s, details: %s",
                        err.message,
                        (err as grpc.ServiceError).code,
                        (err as grpc.ServiceError).details || 'no details')
                    logger.info("============================")
                    return reject(err)
                }

                logger.info("Talk RESPONSE received")
                logger.info("Talk RESPONSE TIME: %s", new Date().toISOString())
                printResponse("Talk RESPONSE", response)
                logger.info("============================")

                return resolve(response)
            })
        } catch (error) {
            logger.error("Talk EXCEPTION: %s",
                error instanceof Error ? error.message : String(error))
            logger.info("============================")
            reject(error)
        }
    })
}

/**
 * Executes a server streaming RPC call
 * Server sends multiple responses for a single request
 * 
 * @param {TalkRequest} request - Request payload
 * @returns {Promise<void>} Resolves when stream completes
 */
function talkOneAnswerMore(request: TalkRequest): Promise<void> {
    logger.info("======== [Server Streaming RPC] ========")
    logger.info("TalkOneAnswerMore REQUEST: data=%s, meta=%s", request.getData(), request.getMeta())
    logger.info("TalkOneAnswerMore REQUEST TIME: %s", new Date().toISOString())

    // Create metadata with request ID for tracing
    const metadata = new grpc.Metadata()
    metadata.add("request-id", `ss-${Date.now()}`)

    return new Promise<void>((resolve, reject) => {
        try {
            // Start the streaming call
            const stream = client.talkOneAnswerMore(request, metadata)
            let responseCount = 0

            // Process incoming response data
            stream.on('data', function (response: TalkResponse) {
                responseCount++
                logger.info("TalkOneAnswerMore RESPONSE #%d received", responseCount)
                printResponse(`TalkOneAnswerMore RESPONSE #${responseCount}`, response)
            })

            // Handle stream completion
            stream.on('end', () => {
                logger.info("TalkOneAnswerMore received %d responses in total", responseCount)
                logger.info("TalkOneAnswerMore COMPLETION TIME: %s", new Date().toISOString())
                logger.info("============================")
                resolve()
            })

            // Handle stream errors
            stream.on('error', (err: Error) => {
                logger.error("TalkOneAnswerMore ERROR: %s, code: %s, details: %s",
                    err.message,
                    (err as grpc.ServiceError).code,
                    (err as grpc.ServiceError).details || 'no details')
                logger.info("============================")
                reject(err)
            })
        } catch (error: unknown) {
            logger.error("TalkOneAnswerMore EXCEPTION: %s",
                error instanceof Error ? error.message : String(error))
            logger.info("============================")
            reject(error)
        }
    })
}

/**
 * Executes a client streaming RPC call
 * Client sends multiple requests and receives a single response
 * 
 * @param {TalkRequest[]} requests - Array of request payloads
 * @returns {Promise<TalkResponse>} Response from the server
 */
function talkMoreAnswerOne(requests: TalkRequest[]): Promise<TalkResponse> {
    logger.info("======== [Client Streaming RPC] ========")
    logger.info("TalkMoreAnswerOne STARTED at: %s", new Date().toISOString())
    logger.info("TalkMoreAnswerOne sending %d requests", requests.length)

    // Create metadata with request ID for tracing
    const metadata = new grpc.Metadata()
    metadata.add("request-id", `cs-${Date.now()}`)

    return new Promise<TalkResponse>((resolve, reject) => {
        try {
            // Start the streaming call
            const call = client.talkMoreAnswerOne(metadata, function (err: Error | null, response: TalkResponse) {
                if (err) {
                    logger.error("TalkMoreAnswerOne CALLBACK ERROR: %s, code: %s, details: %s",
                        err.message,
                        (err as grpc.ServiceError).code,
                        (err as grpc.ServiceError).details || 'no details')
                    logger.info("============================")
                    return reject(err)
                }

                logger.info("TalkMoreAnswerOne RESPONSE received")
                logger.info("TalkMoreAnswerOne COMPLETION TIME: %s", new Date().toISOString())
                printResponse("TalkMoreAnswerOne RESPONSE", response)
                logger.info("============================")

                resolve(response)
            })

            // Handle stream errors
            call.on('error', function (err: Error) {
                logger.error("TalkMoreAnswerOne STREAM ERROR: %s, code: %s, details: %s",
                    err.message,
                    (err as grpc.ServiceError).code,
                    (err as grpc.ServiceError).details || 'no details')
                reject(err)
            })

            // Send each request in sequence
            requests.forEach((request, index) => {
                logger.info("TalkMoreAnswerOne REQUEST #%d: data=%s, meta=%s",
                    index + 1, request.getData(), request.getMeta())
                call.write(request)
            })

            // End the request stream
            call.end()
        } catch (error: unknown) {
            logger.error("TalkMoreAnswerOne EXCEPTION: %s",
                error instanceof Error ? error.message : String(error))
            logger.info("============================")
            reject(error)
        }
    })
}

/**
 * Executes a bidirectional streaming RPC call
 * Client and server exchange multiple messages
 * 
 * @param {TalkRequest[]} requests - Array of request payloads
 * @returns {Promise<void>} Resolves when stream completes
 */
function talkBidirectional(requests: TalkRequest[]): Promise<void> {
    logger.info("======== [Bidirectional Streaming RPC] ========")
    logger.info("TalkBidirectional STARTED at: %s", new Date().toISOString())
    logger.info("TalkBidirectional sending %d requests", requests.length)

    // Create metadata with request ID for tracing
    const metadata = new grpc.Metadata()
    metadata.add("request-id", `bidir-${Date.now()}`)

    return new Promise<void>((resolve, reject) => {
        try {
            // Start the streaming call
            const call = client.talkBidirectional(metadata)
            let responseCount = 0

            // Set up stream event handlers
            call.on('data', function (response: TalkResponse) {
                responseCount++
                logger.info("TalkBidirectional RESPONSE #%d received", responseCount)
                printResponse(`TalkBidirectional RESPONSE #${responseCount}`, response)
            })

            call.on('end', function () {
                logger.info("TalkBidirectional received %d responses in total", responseCount)
                logger.info("TalkBidirectional COMPLETION TIME: %s", new Date().toISOString())
                logger.info("============================")
                resolve()
            })

            call.on('error', function (err: Error) {
                logger.error("TalkBidirectional ERROR: %s, code: %s, details: %s",
                    err.message,
                    (err as grpc.ServiceError).code,
                    (err as grpc.ServiceError).details || 'no details')
                logger.info("============================")
                reject(err)
            })

            // Send each request in the array
            requests.forEach((request, index) => {
                logger.info("TalkBidirectional REQUEST #%d: data=%s, meta=%s",
                    index + 1, request.getData(), request.getMeta())
                call.write(request)
            })

            // End the request stream
            call.end()
        } catch (error: unknown) {
            logger.error("TalkBidirectional EXCEPTION: %s",
                error instanceof Error ? error.message : String(error))
            logger.info("============================")
            reject(error)
        }
    })
}

/**
 * Executes a bidirectional streaming RPC call with dynamic requests
 * Generates requests while receiving responses
 * 
 * @param {number} count - Number of requests to generate
 * @returns {Promise<void>} Resolves when stream completes
 */
function talkBidirectionalInteractive(count: number = 3): Promise<void> {
    logger.info("======== [Interactive Bidirectional Streaming RPC] ========")
    logger.info("TalkBidirectionalInteractive STARTED at: %s", new Date().toISOString())
    logger.info("TalkBidirectionalInteractive will send %d requests", count)

    const metadata = new grpc.Metadata()
    metadata.add("request-id", `bidir-int-${Date.now()}`)

    return new Promise<void>((resolve, reject) => {
        try {
            // Start streaming call
            const call = client.talkBidirectional(metadata)
            let responseCount = 0
            let requestsSent = 0

            // Send a request every second
            const interval = setInterval(() => {
                if (requestsSent >= count) {
                    clearInterval(interval)
                    call.end()
                    return
                }

                try {
                    // Generate a request with random data
                    const request = new TalkRequest()
                    request.setData(randomId(5))
                    request.setMeta("TypeScript-Interactive")

                    requestsSent++
                    logger.info("TalkBidirectionalInteractive REQUEST #%d: data=%s, meta=%s",
                        requestsSent, request.getData(), request.getMeta())

                    call.write(request)
                } catch (error) {
                    logger.error("Error sending request: %s",
                        error instanceof Error ? error.message : String(error))
                    clearInterval(interval)
                    call.end()
                }
            }, 1000)

            // Handle incoming responses
            call.on('data', function (response: TalkResponse) {
                responseCount++
                logger.info("TalkBidirectionalInteractive RESPONSE #%d received", responseCount)
                printResponse(`TalkBidirectionalInteractive RESPONSE #${responseCount}`, response)
            })

            // Handle stream completion
            call.on('end', function () {
                clearInterval(interval)
                logger.info("TalkBidirectionalInteractive sent %d requests and received %d responses",
                    requestsSent, responseCount)
                logger.info("TalkBidirectionalInteractive COMPLETION TIME: %s", new Date().toISOString())
                logger.info("============================")
                resolve()
            })

            // Handle stream errors
            call.on('error', function (err: Error) {
                clearInterval(interval)
                logger.error("TalkBidirectionalInteractive ERROR: %s, code: %s, details: %s",
                    err.message,
                    (err as grpc.ServiceError).code,
                    (err as grpc.ServiceError).details || 'no details')
                logger.info("============================")
                reject(err)
            })
        } catch (error: unknown) {
            logger.error("TalkBidirectionalInteractive EXCEPTION: %s",
                error instanceof Error ? error.message : String(error))
            logger.info("============================")
            reject(error)
        }
    })
}

/**
 * Prints a formatted representation of a gRPC response
 * 
 * @param {string} methodName - Name of the method for logging
 * @param {TalkResponse} response - Response to print
 */
function printResponse(methodName: string, response: TalkResponse): void {
    if (!response) {
        logger.warn("%s: Response is undefined", methodName)
        return
    }

    const status = response.getStatus()
    const resultsList = response.getResultsList()

    if (!resultsList || resultsList.length === 0) {
        logger.info("%s: status=%d, no results", methodName, status)
        return
    }

    logger.info("%s: status=%d, results=%d", methodName, status, resultsList.length)

    resultsList.forEach((result, index) => {
        const kv = result.getKvMap()

        // Extract values with fallbacks
        const meta = kv.get("meta") || ""
        const id = kv.get("id") || ""
        const idx = kv.get("idx") || ""
        const data = kv.get("data") || ""

        logger.info("%s DETAIL #%d: id=%d, type=%d, meta=%s, reqId=%s, idx=%s, data=%s",
            methodName,
            index + 1,
            result.getId(),
            result.getType(),
            meta,
            id,
            idx,
            data
        )
    })
}

/**
 * Creates and initializes the gRPC client
 * 
 * @returns {Promise<LandingServiceClient>} The initialized client
 */
async function createGrpcClient(): Promise<LandingServiceClient> {
    const secure = process.env.GRPC_HELLO_SECURE === 'Y'
    const serverHost = process.env.GRPC_SERVER || DEFAULT_SERVER_HOST
    const serverPort = process.env.GRPC_SERVER_PORT || DEFAULT_SERVER_PORT
    const address = `${serverHost}:${serverPort}`

    logger.info("Creating gRPC client to %s", address)
    logger.info("TLS Mode: %s", secure ? 'Enabled' : 'Disabled')

    if (secure) {
        try {
            // Get TLS credentials from our utility module
            const { credentials, options } = createClientCredentials()
            logger.info("Created TLS credentials successfully")
            return new LandingServiceClient(address, credentials, options)
        } catch (error: unknown) {
            logger.error("Failed to create secure client: %s, falling back to insecure",
                error instanceof Error ? error.message : String(error))
            return new LandingServiceClient(address, grpc.credentials.createInsecure())
        }
    } else {
        logger.info("Using insecure connection")
        return new LandingServiceClient(address, grpc.credentials.createInsecure())
    }
}

/**
 * Executes all gRPC call patterns in sequence
 */
async function runAllPatterns(): Promise<void> {
    logger.info("Running all gRPC communication patterns...")

    try {
        // 1. Unary RPC
        const unaryRequest = new TalkRequest()
        unaryRequest.setData("0")
        unaryRequest.setMeta("TypeScript")
        await talk(unaryRequest)

        // 2. Server Streaming RPC
        const serverStreamRequest = new TalkRequest()
        serverStreamRequest.setData("0,1,2")
        serverStreamRequest.setMeta("TypeScript")
        await talkOneAnswerMore(serverStreamRequest)

        // 3. Client Streaming RPC
        const clientStreamRequests = buildLinkRequests()
        await talkMoreAnswerOne(clientStreamRequests)

        // 4. Bidirectional Streaming RPC (prefabricated)
        await talkBidirectional(buildLinkRequests())

        // 5. Bidirectional Streaming RPC (interactive)
        await talkBidirectionalInteractive(3)

        logger.info("All gRPC patterns executed successfully")
    } catch (error) {
        logger.error("Error executing gRPC patterns: %s",
            error instanceof Error ? error.message : String(error))
        throw error
    }
}

/**
 * Main entry point for client application
 */
async function startClient(): Promise<void> {
    try {
        logger.info("Starting gRPC TypeScript client [version: %s]", getVersion())

        // Initialize the client
        client = await createGrpcClient()

        // Run all RPC patterns
        await runAllPatterns()

        logger.info("Client operations completed successfully")
    } catch (error: unknown) {
        logger.error("Client execution failed: %s",
            error instanceof Error ? error.message : String(error))
        throw error
    }
}

/**
 * Set up signal handlers for graceful shutdown
 */
function setupSignalHandlers(): void {
    // Handle SIGINT (Ctrl+C)
    process.on('SIGINT', () => {
        logger.info("Received SIGINT signal, shutting down client...")
        process.exit(0)
    })

    // Handle SIGTERM
    process.on('SIGTERM', () => {
        logger.info("Received SIGTERM signal, shutting down client...")
        process.exit(0)
    })

    // Add uncaught exception handler
    process.on('uncaughtException', (err) => {
        logger.error('Uncaught Exception: %s', err.message)
        logger.error(err.stack || 'No stack trace available')
        process.exit(1)
    })

    // Add unhandled promise rejection handler
    process.on('unhandledRejection', (reason, promise) => {
        logger.error('Unhandled Promise Rejection at: %s - reason: %s',
            promise,
            reason instanceof Error ? reason.message : String(reason))
    })
}

// Set up signal handlers
setupSignalHandlers()

// Execute client and handle exit
startClient()
    .then(() => {
        logger.info('Client execution completed successfully')
        console.log('Bye 🍎 hello-grpc TypeScript client 🍎')
        // Ensure all logs are flushed
        setTimeout(() => process.exit(0), 500)
    })
    .catch(() => {
        // Error already logged in startClient
        // Ensure all logs are flushed
        setTimeout(() => process.exit(1), 500)
    })