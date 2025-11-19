/**
 * gRPC Client implementation for the Landing service (TypeScript).
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

import * as grpc from '@grpc/grpc-js';
import { TalkRequest, TalkResponse } from './generated/landing_pb';
import { logger } from './lib/conn';
import { buildLinkRequests, getVersion, randomId } from './lib/utils';
import { LandingServiceClient } from './generated/landing_grpc_pb';
import { createClientCredentials } from './lib/tls';

// Configuration constants
const RETRY_ATTEMPTS = 3;
const RETRY_DELAY_SECONDS = 2;
const ITERATION_COUNT = 3;
const REQUEST_DELAY_MS = 200;
const SEND_DELAY_MS = 2;
const REQUEST_TIMEOUT_SECONDS = 5;
const DEFAULT_BATCH_SIZE = 5;
const DEFAULT_SERVER_HOST = 'localhost';
const DEFAULT_SERVER_PORT = '9996';

// Client instance
let client: LandingServiceClient;
let shutdownRequested = false;

/**
 * Set up signal handling for graceful shutdown
 */
function setupSignalHandling(): void {
    process.on('SIGINT', () => {
        logger.info('Received shutdown signal, cancelling operations');
        shutdownRequested = true;
    });

    process.on('SIGTERM', () => {
        logger.info('Received SIGTERM signal, cancelling operations');
        shutdownRequested = true;
    });

    process.on('uncaughtException', (err) => {
        logger.error('Uncaught Exception: %s', err.message);
        logger.error(err.stack || 'No stack trace available');
        process.exit(1);
    });

    process.on('unhandledRejection', (reason) => {
        logger.error('Unhandled Promise Rejection: %s',
            reason instanceof Error ? reason.message : String(reason));
    });
}

/**
 * Sleep for the specified number of milliseconds
 */
function sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Main entry point for the client
 */
async function main(): Promise<void> {
    setupSignalHandling();
    logger.info('Starting gRPC client [version: %s]', getVersion());

    // Retry logic for connection
    for (let attempt = 1; attempt <= RETRY_ATTEMPTS; attempt++) {
        if (shutdownRequested) {
            logger.info('Client shutting down, aborting connection attempts');
            return;
        }

        logger.info('Connection attempt %d/%d', attempt, RETRY_ATTEMPTS);

        try {
            client = await createGrpcClient();

            // Run all gRPC patterns
            const success = await runGrpcCalls(REQUEST_DELAY_MS, ITERATION_COUNT);

            if (success || shutdownRequested) {
                break;
            }
        } catch (err) {
            logger.error('Connection attempt %d failed: %s', attempt,
                err instanceof Error ? err.message : String(err));
            if (attempt < RETRY_ATTEMPTS && !shutdownRequested) {
                logger.info('Retrying in %d seconds...', RETRY_DELAY_SECONDS);
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
 */
async function runGrpcCalls(delayMs: number, iterations: number): Promise<boolean> {
    for (let iteration = 1; iteration <= iterations; iteration++) {
        if (shutdownRequested) {
            return false;
        }

        logger.info('====== Starting iteration %d/%d ======', iteration, iterations);

        try {
            // 1. Unary RPC
            logger.info('----- Executing unary RPC -----');
            const unaryRequest = new TalkRequest();
            unaryRequest.setData('0');
            unaryRequest.setMeta('TypeScript');
            await executeUnaryCall(unaryRequest);

            // 2. Server streaming RPC
            logger.info('----- Executing server streaming RPC -----');
            const serverStreamRequest = new TalkRequest();
            serverStreamRequest.setData('0,1,2');
            serverStreamRequest.setMeta('TypeScript');
            await executeServerStreamingCall(serverStreamRequest);

            // 3. Client streaming RPC
            logger.info('----- Executing client streaming RPC -----');
            const response = await executeClientStreamingCall(buildLinkRequests());
            logResponse(response);

            // 4. Bidirectional streaming RPC
            logger.info('----- Executing bidirectional streaming RPC -----');
            await executeBidirectionalStreamingCall(buildLinkRequests());

            if (iteration < iterations && !shutdownRequested) {
                logger.info('Waiting %dms before next iteration...', delayMs);
                await sleep(delayMs);
            }
        } catch (err) {
            logger.error('Error in iteration %d: %s', iteration,
                err instanceof Error ? err.message : String(err));
            return false;
        }
    }

    logger.info('All gRPC calls completed successfully');
    return true;
}

/**
 * Execute unary RPC call
 */
function executeUnaryCall(request: TalkRequest): Promise<void> {
    return new Promise((resolve, reject) => {
        const requestId = `unary-${Date.now()}`;
        const metadata = new grpc.Metadata();
        metadata.add('request-id', requestId);
        metadata.add('client', 'typescript-client');

        logger.info('Sending unary request: data=%s, meta=%s',
            request.getData(), request.getMeta());
        const startTime = Date.now();

        const deadline = new Date(Date.now() + REQUEST_TIMEOUT_SECONDS * 1000);
        client.talk(request, metadata, { deadline }, (err, response) => {
            const duration = Date.now() - startTime;

            if (err) {
                logError(err, requestId, 'Talk');
                reject(err);
            } else {
                logger.info('Unary call successful in %dms', duration);
                logResponse(response);
                resolve();
            }
        });
    });
}

/**
 * Execute server streaming RPC call
 */
function executeServerStreamingCall(request: TalkRequest): Promise<void> {
    return new Promise((resolve, reject) => {
        const requestId = `server-stream-${Date.now()}`;
        const metadata = new grpc.Metadata();
        metadata.add('request-id', requestId);
        metadata.add('client', 'typescript-client');

        logger.info('Starting server streaming with request: data=%s, meta=%s',
            request.getData(), request.getMeta());
        const startTime = Date.now();

        const stream = client.talkOneAnswerMore(request, metadata);
        let responseCount = 0;

        stream.on('data', (response: TalkResponse) => {
            if (shutdownRequested) {
                logger.info('Server streaming cancelled');
                stream.cancel();
                resolve();
                return;
            }

            responseCount++;
            logger.info('Received server streaming response #%d:', responseCount);
            logResponse(response);
        });

        stream.on('error', (err: Error) => {
            logError(err, requestId, 'TalkOneAnswerMore');
            reject(err);
        });

        stream.on('end', () => {
            const duration = Date.now() - startTime;
            logger.info('Server streaming completed: received %d responses in %dms',
                responseCount, duration);
            resolve();
        });
    });
}

/**
 * Execute client streaming RPC call
 */
function executeClientStreamingCall(requests: TalkRequest[]): Promise<TalkResponse> {
    return new Promise((resolve, reject) => {
        const requestId = `client-stream-${Date.now()}`;
        const metadata = new grpc.Metadata();
        metadata.add('request-id', requestId);
        metadata.add('client', 'typescript-client');

        logger.info('Starting client streaming with %d requests', requests.length);
        const startTime = Date.now();

        const call = client.talkMoreAnswerOne(metadata, (err, response) => {
            const duration = Date.now() - startTime;

            if (err) {
                logError(err, requestId, 'TalkMoreAnswerOne');
                reject(err);
            } else {
                logger.info('Client streaming completed: sent %d requests in %dms',
                    requests.length, duration);
                resolve(response);
            }
        });

        call.on('error', (err: Error) => {
            logError(err, requestId, 'TalkMoreAnswerOne');
            reject(err);
        });

        // Send all requests
        let requestCount = 0;
        const sendNext = () => {
            if (requestCount < requests.length && !shutdownRequested) {
                const request = requests[requestCount];
                requestCount++;
                logger.info('Sending client streaming request #%d: data=%s, meta=%s',
                    requestCount, request.getData(), request.getMeta());
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
 */
function executeBidirectionalStreamingCall(requests: TalkRequest[]): Promise<void> {
    return new Promise((resolve, reject) => {
        const requestId = `bidirectional-${Date.now()}`;
        const metadata = new grpc.Metadata();
        metadata.add('request-id', requestId);
        metadata.add('client', 'typescript-client');

        logger.info('Starting bidirectional streaming with %d requests', requests.length);
        const startTime = Date.now();

        const call = client.talkBidirectional(metadata);
        let responseCount = 0;

        call.on('data', (response: TalkResponse) => {
            if (shutdownRequested) {
                logger.info('Bidirectional streaming cancelled');
                call.cancel();
                resolve();
                return;
            }

            responseCount++;
            logger.info('Received bidirectional streaming response #%d:', responseCount);
            logResponse(response);
        });

        call.on('error', (err: Error) => {
            logError(err, requestId, 'TalkBidirectional');
            reject(err);
        });

        call.on('end', () => {
            const duration = Date.now() - startTime;
            logger.info('Bidirectional streaming completed in %dms', duration);
            resolve();
        });

        // Send all requests
        let requestCount = 0;
        const sendNext = () => {
            if (requestCount < requests.length && !shutdownRequested) {
                const request = requests[requestCount];
                requestCount++;
                logger.info('Sending bidirectional streaming request #%d: data=%s, meta=%s',
                    requestCount, request.getData(), request.getMeta());
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
 * Log response details
 */
function logResponse(response: TalkResponse): void {
    if (!response) {
        logger.warn('Received nil response');
        return;
    }

    const resultsList = response.getResultsList();
    logger.info('Response status: %d, results: %d', response.getStatus(), resultsList.length);

    resultsList.forEach((result, index) => {
        const kv = result.getKvMap();
        logger.info('  Result #%d: id=%d, type=%d, meta=%s, id=%s, idx=%s, data=%s',
            index + 1,
            result.getId(),
            result.getType(),
            kv.get('meta') || '',
            kv.get('id') || '',
            kv.get('idx') || '',
            kv.get('data') || '');
    });
}

/**
 * Log error with context
 */
function logError(error: Error, requestId: string, method: string): void {
    const grpcError = error as grpc.ServiceError;
    logger.error('Request failed - request_id: %s, method: %s, error_code: %s, message: %s',
        requestId,
        method,
        grpcError.code || 'UNKNOWN',
        grpcError.message);
}

/**
 * Create and configure the gRPC client
 */
async function createGrpcClient(): Promise<LandingServiceClient> {
    const secure = process.env.GRPC_HELLO_SECURE === 'Y';
    const serverHost = process.env.GRPC_SERVER || DEFAULT_SERVER_HOST;
    const serverPort = process.env.GRPC_SERVER_PORT || DEFAULT_SERVER_PORT;
    const address = `${serverHost}:${serverPort}`;

    logger.info('Connecting to server: %s', address);
    logger.info('TLS Mode: %s', secure ? 'Enabled' : 'Disabled');

    if (secure) {
        try {
            const { credentials, options } = createClientCredentials();
            logger.info('Created TLS credentials successfully');
            return new LandingServiceClient(address, credentials, options);
        } catch (error) {
            logger.error('Failed to create secure client: %s, falling back to insecure',
                error instanceof Error ? error.message : String(error));
            return new LandingServiceClient(address, grpc.credentials.createInsecure());
        }
    } else {
        logger.info('Using insecure connection');
        return new LandingServiceClient(address, grpc.credentials.createInsecure());
    }
}

// Start the client
main()
    .then(() => {
        logger.info('Client execution completed successfully');
        console.log('Bye 🍎 hello-grpc TypeScript client 🍎');
        setTimeout(() => process.exit(0), 500);
    })
    .catch((err) => {
        logger.error('Fatal error: %s', err instanceof Error ? err.message : String(err));
        setTimeout(() => process.exit(1), 500);
    });
