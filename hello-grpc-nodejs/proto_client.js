/**
 * gRPC Client implementation for the Landing service (Node.js).
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

const grpc = require('@grpc/grpc-js');
const { TalkRequest } = require('./common/landing_pb');
const conn = require('./common/connection');
const utils = require('./common/utils');
const errorMapper = require('./common/errorMapper');

// Configuration constants
const RETRY_ATTEMPTS = 3;
const RETRY_DELAY_SECONDS = 2;
const ITERATION_COUNT = 3;
const REQUEST_DELAY_MS = 200;
const SEND_DELAY_MS = 2;
const REQUEST_TIMEOUT_SECONDS = 5;
const DEFAULT_BATCH_SIZE = 5;

// Logger instance
const logger = conn.logger;

// Shutdown flag
let shutdownRequested = false;

/**
 * Set up signal handling for graceful shutdown
 */
function setupSignalHandling() {
    process.on('SIGINT', () => {
        logger.info('Received shutdown signal, cancelling operations');
        shutdownRequested = true;
    });

    process.on('SIGTERM', () => {
        logger.info('Received SIGTERM signal, cancelling operations');
        shutdownRequested = true;
    });
}

/**
 * Main entry point for the client
 */
async function main() {
    setupSignalHandling();
    logger.info(`Starting gRPC client [version: ${utils.getVersion()}]`);

    // Retry logic for connection
    for (let attempt = 1; attempt <= RETRY_ATTEMPTS; attempt++) {
        if (shutdownRequested) {
            logger.info('Client shutting down, aborting connection attempts');
            return;
        }

        logger.info(`Connection attempt ${attempt}/${RETRY_ATTEMPTS}`);

        try {
            const client = conn.getClient();

            // Run all gRPC patterns
            const success = await runGrpcCalls(client, REQUEST_DELAY_MS, ITERATION_COUNT);

            if (success || shutdownRequested) {
                break;
            }
        } catch (err) {
            logger.error(`Connection attempt ${attempt} failed: ${err.message}`);
            if (attempt < RETRY_ATTEMPTS && !shutdownRequested) {
                logger.info(`Retrying in ${RETRY_DELAY_SECONDS} seconds...`);
                await sleep(RETRY_DELAY_SECONDS * 1000);
            }
        }
    }

    if (shutdownRequested) {
        logger.info('Client execution was cancelled');
    } else {
        logger.info('Client execution completed successfully');
    }
}

/**
 * Run all gRPC call patterns multiple times
 * @param {Object} client - The gRPC client instance
 * @param {number} delayMs - Delay between iterations in milliseconds
 * @param {number} iterations - Number of iterations to run
 * @returns {Promise<boolean>} True if successful, false otherwise
 */
async function runGrpcCalls(client, delayMs, iterations) {
    for (let iteration = 1; iteration <= iterations; iteration++) {
        if (shutdownRequested) {
            return false;
        }

        logger.info(`====== Starting iteration ${iteration}/${iterations} ======`);

        try {
            // 1. Unary RPC
            logger.info('----- Executing unary RPC -----');
            const unaryRequest = new TalkRequest();
            unaryRequest.setData('0');
            unaryRequest.setMeta('NODEJS');
            await executeUnaryCall(client, unaryRequest);

            // 2. Server streaming RPC
            logger.info('----- Executing server streaming RPC -----');
            const serverStreamRequest = new TalkRequest();
            serverStreamRequest.setData('0,1,2');
            serverStreamRequest.setMeta('NODEJS');
            await executeServerStreamingCall(client, serverStreamRequest);

            // 3. Client streaming RPC
            logger.info('----- Executing client streaming RPC -----');
            const response = await executeClientStreamingCall(client, buildLinkRequests());
            logResponse(response);

            // 4. Bidirectional streaming RPC
            logger.info('----- Executing bidirectional streaming RPC -----');
            await executeBidirectionalStreamingCall(client, buildLinkRequests());

            if (iteration < iterations && !shutdownRequested) {
                logger.info(`Waiting ${delayMs}ms before next iteration...`);
                await sleep(delayMs);
            }
        } catch (err) {
            logger.error(`Error in iteration ${iteration}: ${err.message}`);
            return false;
        }
    }

    logger.info('All gRPC calls completed successfully');
    return true;
}

/**
 * Execute unary RPC call
 * @param {Object} client - The gRPC client instance
 * @param {TalkRequest} request - The request to send
 * @returns {Promise<void>}
 */
function executeUnaryCall(client, request) {
    return new Promise((resolve, reject) => {
        const requestId = `unary-${Date.now()}`;
        const metadata = new grpc.Metadata();
        metadata.add('request-id', requestId);
        metadata.add('client', 'nodejs-client');

        logger.info(`Sending unary request: data=${request.getData()}, meta=${request.getMeta()}`);
        const startTime = Date.now();

        client.talk(request, metadata, (err, response) => {
            const duration = Date.now() - startTime;

            if (err) {
                errorMapper.logError(err, requestId, 'Talk');
                reject(err);
            } else {
                logger.info(`Unary call successful in ${duration}ms`);
                logResponse(response);
                resolve();
            }
        });
    });
}

/**
 * Execute server streaming RPC call
 * @param {Object} client - The gRPC client instance
 * @param {TalkRequest} request - The request to send
 * @returns {Promise<void>}
 */
function executeServerStreamingCall(client, request) {
    return new Promise((resolve, reject) => {
        const requestId = `server-stream-${Date.now()}`;
        const metadata = new grpc.Metadata();
        metadata.add('request-id', requestId);
        metadata.add('client', 'nodejs-client');

        logger.info(`Starting server streaming with request: data=${request.getData()}, meta=${request.getMeta()}`);
        const startTime = Date.now();

        const call = client.talkOneAnswerMore(request, metadata);
        let responseCount = 0;

        call.on('data', (response) => {
            if (shutdownRequested) {
                logger.info('Server streaming cancelled');
                call.cancel();
                resolve();
                return;
            }

            responseCount++;
            logger.info(`Received server streaming response #${responseCount}:`);
            logResponse(response);
        });

        call.on('error', (err) => {
            errorMapper.logError(err, requestId, 'TalkOneAnswerMore');
            reject(err);
        });

        call.on('end', () => {
            const duration = Date.now() - startTime;
            logger.info(`Server streaming completed: received ${responseCount} responses in ${duration}ms`);
            resolve();
        });
    });
}

/**
 * Execute client streaming RPC call
 * @param {Object} client - The gRPC client instance
 * @param {Array<TalkRequest>} requests - The requests to send
 * @returns {Promise<Object>} The response
 */
function executeClientStreamingCall(client, requests) {
    return new Promise((resolve, reject) => {
        const requestId = `client-stream-${Date.now()}`;
        const metadata = new grpc.Metadata();
        metadata.add('request-id', requestId);
        metadata.add('client', 'nodejs-client');

        logger.info(`Starting client streaming with ${requests.length} requests`);
        const startTime = Date.now();

        const call = client.talkMoreAnswerOne(metadata, (err, response) => {
            const duration = Date.now() - startTime;

            if (err) {
                errorMapper.logError(err, requestId, 'TalkMoreAnswerOne');
                reject(err);
            } else {
                logger.info(`Client streaming completed: sent ${requests.length} requests in ${duration}ms`);
                resolve(response);
            }
        });

        call.on('error', (err) => {
            errorMapper.logError(err, requestId, 'TalkMoreAnswerOne');
            reject(err);
        });

        // Send all requests
        let requestCount = 0;
        const sendNext = () => {
            if (requestCount < requests.length && !shutdownRequested) {
                const request = requests[requestCount];
                requestCount++;
                logger.info(`Sending client streaming request #${requestCount}: data=${request.getData()}, meta=${request.getMeta()}`);
                call.write(request);

                setTimeout(sendNext, SEND_DELAY_MS);
            } else {
                if (shutdownRequested) {
                    logger.info('Client streaming cancelled');
                }
                call.end();
            }
        };

        sendNext();
    });
}

/**
 * Execute bidirectional streaming RPC call
 * @param {Object} client - The gRPC client instance
 * @param {Array<TalkRequest>} requests - The requests to send
 * @returns {Promise<void>}
 */
function executeBidirectionalStreamingCall(client, requests) {
    return new Promise((resolve, reject) => {
        const requestId = `bidirectional-${Date.now()}`;
        const metadata = new grpc.Metadata();
        metadata.add('request-id', requestId);
        metadata.add('client', 'nodejs-client');

        logger.info(`Starting bidirectional streaming with ${requests.length} requests`);
        const startTime = Date.now();

        const call = client.talkBidirectional(metadata);
        let responseCount = 0;

        call.on('data', (response) => {
            if (shutdownRequested) {
                logger.info('Bidirectional streaming cancelled');
                call.cancel();
                resolve();
                return;
            }

            responseCount++;
            logger.info(`Received bidirectional streaming response #${responseCount}:`);
            logResponse(response);
        });

        call.on('error', (err) => {
            errorMapper.logError(err, requestId, 'TalkBidirectional');
            reject(err);
        });

        call.on('end', () => {
            const duration = Date.now() - startTime;
            logger.info(`Bidirectional streaming completed in ${duration}ms`);
            resolve();
        });

        // Send all requests
        let requestCount = 0;
        const sendNext = () => {
            if (requestCount < requests.length && !shutdownRequested) {
                const request = requests[requestCount];
                requestCount++;
                logger.info(`Sending bidirectional streaming request #${requestCount}: data=${request.getData()}, meta=${request.getMeta()}`);
                call.write(request);

                setTimeout(sendNext, SEND_DELAY_MS);
            } else {
                if (shutdownRequested) {
                    logger.info('Bidirectional streaming cancelled');
                }
                call.end();
            }
        };

        sendNext();
    });
}

/**
 * Build a list of link requests for testing streaming RPCs
 * @returns {Array<TalkRequest>} Array of requests
 */
function buildLinkRequests() {
    const requests = [];
    for (let i = 0; i < DEFAULT_BATCH_SIZE; i++) {
        const request = new TalkRequest();
        request.setData(utils.randomId(5));
        request.setMeta('NODEJS');
        requests.push(request);
    }
    return requests;
}

/**
 * Log response details
 * @param {Object} response - The response to log
 */
function logResponse(response) {
    if (!response) {
        logger.warn('Received nil response');
        return;
    }

    const resultsList = response.getResultsList();
    logger.info(`Response status: ${response.getStatus()}, results: ${resultsList.length}`);

    resultsList.forEach((result, index) => {
        const kv = result.getKvMap();
        logger.info(`  Result #${index + 1}: id=${result.getId()}, type=${result.getType()}, ` +
            `meta=${kv.get('meta')}, id=${kv.get('id')}, idx=${kv.get('idx')}, data=${kv.get('data')}`);
    });
}

/**
 * Sleep for the specified number of milliseconds
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise<void>}
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Start the client
main().catch(err => {
    logger.error(`Fatal error: ${err.message}`);
    process.exit(1);
});
