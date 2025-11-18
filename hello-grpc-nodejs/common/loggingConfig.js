/**
 * Logging configuration for standardized logging setup.
 * 
 * Provides utilities to initialize logging with standard format:
 * [TIMESTAMP] [LEVEL] [COMPONENT] MESSAGE [CONTEXT]
 * 
 * Uses winston with dual output (console and file).
 */

const winston = require('winston');
const fs = require('fs');
const path = require('path');

const DEFAULT_LOG_DIR = 'logs';
const TIMESTAMP_FORMAT = 'YYYY-MM-DD HH:mm:ss.SSS';

/**
 * Custom format for standard log output
 */
const standardFormat = (component) => winston.format.printf(({ timestamp, level, message, ...metadata }) => {
    let log = `[${timestamp}] [${level.toUpperCase()}] [${component}] ${message}`;
    
    // Add context if present
    const contextKeys = Object.keys(metadata).filter(key => 
        key !== 'timestamp' && key !== 'level' && key !== 'message' && key !== Symbol.for('level')
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
function getLogLevel() {
    const level = process.env.LOG_LEVEL || 'info';
    return level.toLowerCase();
}

/**
 * Initialize logging for a component with dual output (console and file)
 * 
 * @param {string} component - The component name (e.g., "client", "server")
 * @param {string} logDir - The directory for log files (default: "logs")
 * @param {boolean} enableFile - Whether to enable file logging (default: true)
 * @returns {winston.Logger} Logger instance for the component
 */
function initializeLogging(component, logDir = DEFAULT_LOG_DIR, enableFile = true) {
    // Create log directory
    if (enableFile && !fs.existsSync(logDir)) {
        fs.mkdirSync(logDir, { recursive: true });
    }

    const level = getLogLevel();
    const transports = [];

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
 * @param {winston.Logger} logger - Parent logger
 * @param {Object} context - Additional context to include in all log messages
 * @returns {winston.Logger} Child logger with context
 */
function createChildLogger(logger, context) {
    return logger.child(context);
}

module.exports = {
    initializeLogging,
    createChildLogger,
    getLogLevel
};
