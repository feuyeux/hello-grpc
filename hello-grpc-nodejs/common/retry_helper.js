/**
 * Retry helper for gRPC client calls.
 * 
 * Implements unified retry strategy:
 * - Max 3 retries (4 total attempts)
 * - Exponential backoff: 0.2s, 0.4s, 0.8s
 * - Retryable status codes: UNAVAILABLE, DEADLINE_EXCEEDED
 */

const grpc = require('@grpc/grpc-js');
const logger = require('./connection').logger;

// Retry configuration
const MAX_RETRY_ATTEMPTS = 3; // Max retries (total attempts = 4)
const INITIAL_BACKOFF = 200; // Initial backoff in milliseconds
const BACKOFF_MULTIPLIER = 2.0; // Exponential backoff multiplier
const MAX_BACKOFF = 2000; // Maximum backoff in milliseconds

// Retryable gRPC status codes
const RETRYABLE_STATUS_CODES = new Set([
    grpc.status.UNAVAILABLE,
    grpc.status.DEADLINE_EXCEEDED,
]);

/**
 * Sleep for a specified duration
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise<void>}
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Check if a gRPC error is retryable
 * @param {Error} error - The error to check
 * @returns {boolean} True if the error is retryable
 */
function isRetryableError(error) {
    if (!error || !error.code) {
        return false;
    }
    return RETRYABLE_STATUS_CODES.has(error.code);
}

/**
 * Wraps a gRPC call with retry logic
 * @param {Function} callFunc - The gRPC call function to execute
 * @param {string} methodName - Name of the method for logging
 * @returns {Promise<any>} The result of the gRPC call
 */
async function withRetry(callFunc, methodName = 'gRPC call') {
    let lastError = null;
    let backoff = INITIAL_BACKOFF;

    for (let attempt = 0; attempt <= MAX_RETRY_ATTEMPTS; attempt++) {
        try {
            return await callFunc();
        } catch (error) {
            lastError = error;

            // Check if this is a retryable error
            if (!isRetryableError(error)) {
                logger.error(`Non-retryable error in ${methodName}: ${error.code} - ${error.message}`);
                throw error;
            }

            // Check if we've exhausted retries
            if (attempt >= MAX_RETRY_ATTEMPTS) {
                logger.error(`Max retry attempts (${MAX_RETRY_ATTEMPTS}) reached for ${methodName}`);
                throw error;
            }

            // Log retry attempt
            logger.warn(
                `Retry attempt ${attempt + 1}/${MAX_RETRY_ATTEMPTS} for ${methodName} ` +
                `after ${error.code} error. Backing off for ${backoff}ms`
            );

            // Wait before retrying
            await sleep(backoff);

            // Calculate next backoff with exponential increase
            backoff = Math.min(backoff * BACKOFF_MULTIPLIER, MAX_BACKOFF);
        }
    }

    // This should never be reached, but just in case
    if (lastError) {
        throw lastError;
    }
}

/**
 * Wraps a callback-based gRPC call with retry logic
 * @param {Function} callFunc - The gRPC call function that takes a callback
 * @param {string} methodName - Name of the method for logging
 * @returns {Promise<any>} The result of the gRPC call
 */
function withRetryCallback(callFunc, methodName = 'gRPC call') {
    return withRetry(() => {
        return new Promise((resolve, reject) => {
            callFunc((err, response) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(response);
                }
            });
        });
    }, methodName);
}

module.exports = {
    withRetry,
    withRetryCallback,
    isRetryableError,
    MAX_RETRY_ATTEMPTS,
    INITIAL_BACKOFF,
    BACKOFF_MULTIPLIER,
    MAX_BACKOFF,
};
