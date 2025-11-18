/**
 * Manages graceful shutdown of the application
 */

const logger = require('./loggingConfig');

const DEFAULT_SHUTDOWN_TIMEOUT = 30000; // milliseconds

class ShutdownHandler {
  constructor(timeout = DEFAULT_SHUTDOWN_TIMEOUT) {
    this.timeout = timeout;
    this.cleanupFunctions = [];
    this.shutdownInitiated = false;
    this.shutdownPromise = null;
    this.shutdownResolve = null;

    // Create a promise that resolves when shutdown is initiated
    this.shutdownPromise = new Promise((resolve) => {
      this.shutdownResolve = resolve;
    });

    // Register signal handlers
    this._registerSignalHandlers();
  }

  /**
   * Registers signal handlers for SIGINT and SIGTERM
   */
  _registerSignalHandlers() {
    process.on('SIGINT', () => {
      logger.info('Received SIGINT signal');
      this.initiateShutdown();
    });

    process.on('SIGTERM', () => {
      logger.info('Received SIGTERM signal');
      this.initiateShutdown();
    });

    // Handle uncaught exceptions
    process.on('uncaughtException', (error) => {
      logger.error(`Uncaught exception: ${error.message}`, error);
      this.initiateShutdown();
    });

    // Handle unhandled promise rejections
    process.on('unhandledRejection', (reason, promise) => {
      logger.error(`Unhandled rejection at: ${promise}, reason: ${reason}`);
      this.initiateShutdown();
    });
  }

  /**
   * Registers a cleanup function to be called during shutdown
   * @param {Function} cleanupFn - The cleanup function (can be async)
   */
  registerCleanup(cleanupFn) {
    this.cleanupFunctions.push(cleanupFn);
  }

  /**
   * Initiates the shutdown process
   */
  initiateShutdown() {
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
   * @returns {Promise<void>}
   */
  async wait() {
    await this.shutdownPromise;
  }

  /**
   * Performs graceful shutdown with timeout
   * @returns {Promise<boolean>} true if shutdown completed successfully, false if timeout occurred
   */
  async shutdown() {
    logger.info('Starting graceful shutdown...');

    try {
      // Create a timeout promise
      const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => reject(new Error('Shutdown timeout')), this.timeout);
      });

      // Execute cleanup functions in reverse order (LIFO)
      const cleanupPromise = (async () => {
        let hasErrors = false;
        for (let i = this.cleanupFunctions.length - 1; i >= 0; i--) {
          try {
            await Promise.resolve(this.cleanupFunctions[i]());
          } catch (error) {
            logger.error(`Error during cleanup: ${error.message}`, error);
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
      if (error.message === 'Shutdown timeout') {
        logger.warn('Shutdown timeout exceeded, forcing shutdown');
        return false;
      }
      logger.error(`Error during shutdown: ${error.message}`, error);
      return false;
    }
  }

  /**
   * Waits for a shutdown signal and then performs shutdown
   * @returns {Promise<boolean>} true if shutdown completed successfully, false if timeout occurred
   */
  async waitAndShutdown() {
    await this.wait();
    return await this.shutdown();
  }
}

module.exports = ShutdownHandler;
