/**
 * Manages graceful shutdown of the application
 */

import { initializeLogging } from './loggingConfig';

const logger = initializeLogging('shutdownHandler', 'logs', false);

const DEFAULT_SHUTDOWN_TIMEOUT = 30000; // milliseconds

export class ShutdownHandler {
  private timeout: number;
  private cleanupFunctions: Array<() => void | Promise<void>>;
  private shutdownInitiated: boolean;
  private shutdownPromise: Promise<void>;
  private shutdownResolve: (() => void) | null;

  constructor(timeout: number = DEFAULT_SHUTDOWN_TIMEOUT) {
    this.timeout = timeout;
    this.cleanupFunctions = [];
    this.shutdownInitiated = false;
    this.shutdownResolve = null;

    // Create a promise that resolves when shutdown is initiated
    this.shutdownPromise = new Promise<void>((resolve) => {
      this.shutdownResolve = resolve;
    });

    // Register signal handlers
    this.registerSignalHandlers();
  }

  /**
   * Registers signal handlers for SIGINT and SIGTERM
   */
  private registerSignalHandlers(): void {
    process.on('SIGINT', () => {
      logger.info('Received SIGINT signal');
      this.initiateShutdown();
    });

    process.on('SIGTERM', () => {
      logger.info('Received SIGTERM signal');
      this.initiateShutdown();
    });

    // Handle uncaught exceptions
    process.on('uncaughtException', (error: Error) => {
      logger.error(`Uncaught exception: ${error.message}`, error);
      this.initiateShutdown();
    });

    // Handle unhandled promise rejections
    process.on('unhandledRejection', (reason: any, promise: Promise<any>) => {
      logger.error(`Unhandled rejection at: ${promise}, reason: ${reason}`);
      this.initiateShutdown();
    });
  }

  /**
   * Registers a cleanup function to be called during shutdown
   * @param cleanupFn - The cleanup function (can be async)
   */
  registerCleanup(cleanupFn: () => void | Promise<void>): void {
    this.cleanupFunctions.push(cleanupFn);
  }

  /**
   * Initiates the shutdown process
   */
  initiateShutdown(): void {
    if (this.shutdownInitiated) {
      return;
    }
    this.shutdownInitiated = true;
    if (this.shutdownResolve) {
      this.shutdownResolve();
    }
  }

  /**
   * Waits for a shutdown signal
   */
  async wait(): Promise<void> {
    await this.shutdownPromise;
  }

  /**
   * Performs graceful shutdown with timeout
   * @returns true if shutdown completed successfully, false if timeout occurred
   */
  async shutdown(): Promise<boolean> {
    logger.info('Starting graceful shutdown...');

    try {
      // Create a timeout promise
      const timeoutPromise = new Promise<never>((_, reject) => {
        setTimeout(() => reject(new Error('Shutdown timeout')), this.timeout);
      });

      // Execute cleanup functions in reverse order (LIFO)
      const cleanupPromise = (async (): Promise<boolean> => {
        let hasErrors = false;
        for (let i = this.cleanupFunctions.length - 1; i >= 0; i--) {
          try {
            await Promise.resolve(this.cleanupFunctions[i]());
          } catch (error) {
            const err = error as Error;
            logger.error(`Error during cleanup: ${err.message}`, err);
            hasErrors = true;
          }
        }
        return hasErrors;
      })();

      // Race between cleanup and timeout
      const hasErrors = await Promise.race([cleanupPromise, timeoutPromise]);

      if (hasErrors) {
        logger.warn('Shutdown completed with errors');
      } else {
        logger.info('Graceful shutdown completed successfully');
      }
      return !hasErrors;

    } catch (error) {
      const err = error as Error;
      if (err.message === 'Shutdown timeout') {
        logger.warn('Shutdown timeout exceeded, forcing shutdown');
        return false;
      }
      logger.error(`Error during shutdown: ${err.message}`, err);
      return false;
    }
  }

  /**
   * Waits for a shutdown signal and then performs shutdown
   * @returns true if shutdown completed successfully, false if timeout occurred
   */
  async waitAndShutdown(): Promise<boolean> {
    await this.wait();
    return await this.shutdown();
  }
}
