/**
 * Logging configuration for standardized logging setup.
 * 
 * Provides utilities to initialize logging with standard format:
 * [TIMESTAMP] [LEVEL] [COMPONENT] MESSAGE [CONTEXT]
 * 
 * Uses winston with dual output (console and file).
 */

import winston from 'winston';
import * as fs from 'fs';
import * as path from 'path';

const DEFAULT_LOG_DIR = 'logs';
const TIMESTAMP_FORMAT = 'YYYY-MM-DD HH:mm:ss.SSS';

/**
 * Custom format for standard log output
 */
const standardFormat = (component: string) => winston.format.printf(({ timestamp, level, message, ...metadata }) => {
    let log = `[${timestamp}] [${level.toUpperCase()}] [${component}] ${message}`;
    
    // Add context if present
    const levelSymbol = Symbol.for('level');
    const contextKeys = Object.keys(metadata).filter(key => 
        key !== 'timestamp' && key !== 'level' && key !== 'message' && key !== levelSymbol.toString()
    );
    
    if (contextKeys.length > 0) {
        const context = contextKeys.map(key => `${key}=${metadata[key]}`).join(', ');
        log += ` [${context}]`;
    }
    
    return log;
});

/**
 * Get log level from environment variable or default to 'info'
 */
function getLogLevel(): string {
    const level = process.env.LOG_LEVEL || 'info';
    return level.toLowerCase();
}

/**
 * Initialize logging for a component with dual output (console and file)
 * 
 * @param component - The component name (e.g., "client", "server")
 * @param logDir - The directory for log files (default: "logs")
 * @param enableFile - Whether to enable file logging (default: true)
 * @returns Logger instance for the component
 */
export function initializeLogging(
    component: string, 
    logDir: string = DEFAULT_LOG_DIR, 
    enableFile: boolean = true
): winston.Logger {
    // Create log directory
    if (enableFile && !fs.existsSync(logDir)) {
        fs.mkdirSync(logDir, { recursive: true });
    }

    const level = getLogLevel();
    const transports: winston.transport[] = [];

    // Console transport
    transports.push(
        new winston.transports.Console({
            level: level,
            format: winston.format.combine(
                winston.format.colorize(),
                winston.format.timestamp({ format: TIMESTAMP_FORMAT }),
                standardFormat(component)
            )
        })
    );

    // File transport
    if (enableFile) {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
        const logFileName = `${component}_${timestamp}.log`;
        const logFilePath = path.join(logDir, logFileName);

        transports.push(
            new winston.transports.File({
                filename: logFilePath,
                level: level,
                format: winston.format.combine(
                    winston.format.timestamp({ format: TIMESTAMP_FORMAT }),
                    standardFormat(component)
                ),
                maxsize: 100 * 1024 * 1024, // 100MB
                maxFiles: 7
            })
        );
    }

    // Create logger
    const logger = winston.createLogger({
        level: level,
        transports: transports,
        exitOnError: false
    });

    logger.info(`Logging initialized for component: ${component}`);
    if (enableFile) {
        logger.info(`Log directory: ${logDir}`);
    }

    return logger;
}

/**
 * Create a child logger with additional context
 * 
 * @param logger - Parent logger
 * @param context - Additional context to include in all log messages
 * @returns Child logger with context
 */
export function createChildLogger(logger: winston.Logger, context: Record<string, any>): winston.Logger {
    return logger.child(context);
}

export { getLogLevel };
