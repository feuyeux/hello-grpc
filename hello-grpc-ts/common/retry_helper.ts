/**
 * Retry helper for gRPC client calls.
 * 
 * Implements unified retry strategy:
 * - Max 3 retries (4 total attempts)
 * - Exponential backoff: 0.2s, 0.4s, 0.8s
 * - Retryable status codes: UNAVAILABLE, DEADLINE_EXCEEDED
 */

import * as grpc from '@grpc/grpc-js';
import { logger } from './conn';

// Retry configuration
export const MAX_RETRY_ATTEMPTS = 3; // Max retries (total attempts = 4)
export const INITIAL_BACKOFF = 200; // Initial backoff in milliseconds
export const BACKOFF_MULTIPLIER = 2.0; // Exponential backoff multiplier
export const MAX_BACKOFF = 2000; // Maximum backoff in milliseconds

// Retryable gRPC status codes
const RETRYABLE_STATUS_CODES = new Set([
    grpc.status.UNAVAILABLE,
    grpc.status.DEADLINE_EXCEEDED,
]);

/**
 * Sleep for a specified duration
 * @param ms - Milliseconds to sleep
 * @returns Promise that resolves after the specified duration
 */
function sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Check if a gRPC error is retryable
 * @param error - The error to check
 * @returns True if the error is retryable
 */
export function isRetryableError(error: any): boolean {
    if (!error || typeof error.code === 'undefined') {
        return false;
    }
    return RETRYABLE_STATUS_CODES.has(error.code);
}

/**
 * Wraps a gRPC call with retry logic
 * @param callFunc - The gRPC call function to execute
 * @param methodName - Name of the method for logging
 * @returns The result of the gRPC call
 */
export async function withRetry<T>(
    callFunc: () => Promise<T>,
    methodName: string = 'gRPC call'
): Promise<T> {
    let lastError: any = null;
    let backoff = INITIAL_BACKOFF;

    for (let attempt = 0; attempt <= MAX_RETRY_ATTEMPTS; attempt++) {
        try {
            return await callFunc();
        } catch (error: any) {
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
    
    // TypeScript requires a return statement here even though it's unreachable
    throw new Error('Unexpected: retry loop completed without returning or throwing');
}

/**
 * Wraps a callback-based gRPC call with retry logic
 * @param callFunc - The gRPC call function that takes a callback
 * @param methodName - Name of the method for logging
 * @returns The result of the gRPC call
 */
export function withRetryCallback<T>(
    callFunc: (callback: (err: Error | null, response: T) => void) => void,
    methodName: string = 'gRPC call'
): Promise<T> {
    return withRetry(() => {
        return new Promise<T>((resolve, reject) => {
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
