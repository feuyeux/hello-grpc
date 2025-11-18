<?php

namespace Common\Utils;

use Exception;

/**
 * Manages graceful shutdown of the application
 */
class ShutdownHandler
{
    private const DEFAULT_SHUTDOWN_TIMEOUT = 30; // seconds

    private float $timeout;
    private array $cleanupFunctions = [];
    private bool $shutdownInitiated = false;

    public function __construct(float $timeout = self::DEFAULT_SHUTDOWN_TIMEOUT)
    {
        $this->timeout = $timeout;
        $this->registerSignalHandlers();
    }

    /**
     * Registers signal handlers for SIGINT and SIGTERM
     */
    private function registerSignalHandlers(): void
    {
        if (function_exists('pcntl_signal')) {
            pcntl_signal(SIGINT, [$this, 'handleSignal']);
            pcntl_signal(SIGTERM, [$this, 'handleSignal']);
            
            // Enable async signals
            if (function_exists('pcntl_async_signals')) {
                pcntl_async_signals(true);
            }
        }
    }

    /**
     * Signal handler callback
     *
     * @param int $signal The signal number
     */
    public function handleSignal(int $signal): void
    {
        $logger = LoggingConfig::getLogger();
        $signalName = $signal === SIGINT ? 'SIGINT' : 'SIGTERM';
        $logger->info("Received $signalName signal");
        $this->initiateShutdown();
    }

    /**
     * Registers a cleanup function to be called during shutdown
     *
     * @param callable $cleanupFn The cleanup function
     */
    public function registerCleanup(callable $cleanupFn): void
    {
        $this->cleanupFunctions[] = $cleanupFn;
    }

    /**
     * Initiates the shutdown process
     */
    public function initiateShutdown(): void
    {
        if ($this->shutdownInitiated) {
            return;
        }
        $this->shutdownInitiated = true;
        
        $logger = LoggingConfig::getLogger();
        $logger->info("Shutdown initiated");
    }

    /**
     * Checks if shutdown has been initiated
     *
     * @return bool
     */
    public function isShutdownInitiated(): bool
    {
        return $this->shutdownInitiated;
    }

    /**
     * Waits for a shutdown signal
     */
    public function wait(): void
    {
        while (!$this->shutdownInitiated) {
            if (function_exists('pcntl_signal_dispatch')) {
                pcntl_signal_dispatch();
            }
            usleep(100000); // 100ms
        }
    }

    /**
     * Performs graceful shutdown with timeout
     *
     * @return bool true if shutdown completed successfully, false if timeout occurred
     */
    public function shutdown(): bool
    {
        $logger = LoggingConfig::getLogger();
        $logger->info("Starting graceful shutdown...");

        $startTime = microtime(true);
        $hasErrors = false;

        // Execute cleanup functions in reverse order (LIFO)
        $reversedCleanup = array_reverse($this->cleanupFunctions);
        
        foreach ($reversedCleanup as $cleanupFn) {
            try {
                $cleanupFn();
            } catch (Exception $e) {
                $logger->error("Error during cleanup: " . $e->getMessage());
                $hasErrors = true;
            }

            // Check if we've exceeded the timeout
            $elapsed = microtime(true) - $startTime;
            if ($elapsed > $this->timeout) {
                $logger->warning("Shutdown timeout exceeded, forcing shutdown");
                return false;
            }
        }

        if ($hasErrors) {
            $logger->warning("Shutdown completed with errors");
        } else {
            $logger->info("Graceful shutdown completed successfully");
        }

        return !$hasErrors;
    }

    /**
     * Waits for a shutdown signal and then performs shutdown
     *
     * @return bool true if shutdown completed successfully, false if timeout occurred
     */
    public function waitAndShutdown(): bool
    {
        $this->wait();
        return $this->shutdown();
    }
}
