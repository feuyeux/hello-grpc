<?php
/**
 * Logging configuration for standardized logging setup.
 * 
 * Provides utilities to initialize logging with standard format:
 * [TIMESTAMP] [LEVEL] [COMPONENT] MESSAGE [CONTEXT]
 * 
 * Uses Monolog with dual output (console and file).
 */

namespace Common\Utils;

use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Monolog\Handler\RotatingFileHandler;
use Monolog\Formatter\LineFormatter;

class LoggingConfig
{
    private const DEFAULT_LOG_DIR = 'logs';
    private const TIMESTAMP_FORMAT = 'Y-m-d H:i:s.v';
    private const LOG_FORMAT = "[%datetime%] [%level_name%] [%channel%] %message% %context%\n";

    /**
     * Initialize logging for a component with dual output (console and file)
     * 
     * @param string $component The component name (e.g., "client", "server")
     * @param string|null $logDir The directory for log files (default: "logs")
     * @param bool $enableFile Whether to enable file logging (default: true)
     * @return Logger Logger instance for the component
     */
    public static function initializeLogging(
        string $component,
        ?string $logDir = null,
        bool $enableFile = true
    ): Logger {
        if ($logDir === null) {
            $logDir = self::DEFAULT_LOG_DIR;
        }

        // Create log directory
        if ($enableFile && !is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }

        // Get log level
        $level = self::getLogLevel();

        // Create logger
        $logger = new Logger($component);

        // Create formatter
        $formatter = new LineFormatter(
            self::LOG_FORMAT,
            self::TIMESTAMP_FORMAT,
            true,  // Allow inline line breaks
            true   // Ignore empty context
        );

        // Add console handler
        $consoleHandler = new StreamHandler('php://stdout', $level);
        $consoleHandler->setFormatter($formatter);
        $logger->pushHandler($consoleHandler);

        // Add file handler if enabled
        if ($enableFile) {
            $timestamp = date('Ymd_His');
            $logFileName = sprintf('%s_%s.log', $component, $timestamp);
            $logFilePath = $logDir . DIRECTORY_SEPARATOR . $logFileName;

            $fileHandler = new RotatingFileHandler(
                $logFilePath,
                7,              // Keep 7 days of logs
                $level,
                true,           // Bubble
                0644,           // File permissions
                false           // Use locking
            );
            $fileHandler->setFormatter($formatter);
            $logger->pushHandler($fileHandler);

            $logger->info(sprintf('Logging initialized for component: %s', $component));
            $logger->info(sprintf('Log file: %s', $logFilePath));
        } else {
            $logger->info(sprintf('Logging initialized for component: %s (console only)', $component));
        }

        return $logger;
    }

    /**
     * Get log level from environment variable or default to INFO
     * 
     * @return int The Monolog log level constant
     */
    private static function getLogLevel(): int
    {
        $levelStr = strtoupper(getenv('LOG_LEVEL') ?: 'INFO');

        $levelMap = [
            'DEBUG' => Logger::DEBUG,
            'INFO' => Logger::INFO,
            'NOTICE' => Logger::NOTICE,
            'WARN' => Logger::WARNING,
            'WARNING' => Logger::WARNING,
            'ERROR' => Logger::ERROR,
            'CRITICAL' => Logger::CRITICAL,
            'ALERT' => Logger::ALERT,
            'EMERGENCY' => Logger::EMERGENCY,
        ];

        return $levelMap[$levelStr] ?? Logger::INFO;
    }

    /**
     * Create a child logger with additional context
     * 
     * @param Logger $logger Parent logger
     * @param array $context Additional context to include in all log messages
     * @return Logger Child logger with context
     */
    public static function createChildLogger(Logger $logger, array $context): Logger
    {
        return $logger->withName($logger->getName())->pushProcessor(
            function ($record) use ($context) {
                $record['context'] = array_merge($context, $record['context']);
                return $record;
            }
        );
    }
}
