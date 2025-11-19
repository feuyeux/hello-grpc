import Foundation
import Logging

/// Logging configuration for standardized logging setup.
///
/// Provides utilities to initialize logging with standard format:
/// [TIMESTAMP] [LEVEL] [COMPONENT] MESSAGE [CONTEXT]
///
/// Uses Swift's Logging framework with dual output (console and file).
public struct LoggingConfig {
    public static let defaultLogDir = "logs"
    
    /// Initialize logging for a component with dual output (console and file)
    ///
    /// - Parameters:
    ///   - component: The component name (e.g., "client", "server")
    ///   - logDir: The directory for log files (default: "logs")
    ///   - enableFile: Whether to enable file logging (default: true)
    /// - Returns: Logger instance for the component
    public static func initializeLogging(
        component: String,
        logDir: String = defaultLogDir,
        enableFile: Bool = true
    ) -> Logger {
        // Create log directory
        if enableFile {
            let fileManager = FileManager.default
            let logDirURL = URL(fileURLWithPath: logDir)
            if !fileManager.fileExists(atPath: logDir) {
                try? fileManager.createDirectory(at: logDirURL, withIntermediateDirectories: true)
            }
        }
        
        // Get log level
        let level = getLogLevel()
        
        // Create log file if enabled
        var logFileHandle: FileHandle?
        if enableFile {
            let timestamp = DateFormatter.fileTimestamp.string(from: Date())
            let logFileName = "\(component)_\(timestamp).log"
            let logFilePath = "\(logDir)/\(logFileName)"
            
            // Create or open log file
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: logFilePath) {
                fileManager.createFile(atPath: logFilePath, contents: nil)
            }
            logFileHandle = FileHandle(forWritingAtPath: logFilePath)
        }
        
        // Bootstrap logging with custom handler
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = level
            
            if let fileHandle = logFileHandle {
                return MultiplexLogHandler([
                    handler,
                    FileLogHandler(label: label, fileHandle: fileHandle, logLevel: level)
                ])
            }
            
            return handler
        }
        
        // Create logger
        var logger = Logger(label: component)
        logger.logLevel = level
        logger.info("Logging initialized for component: \(component)")
        if enableFile {
            logger.info("Log directory: \(logDir)")
        }
        
        return logger
    }
    
    /// Get log level from environment variable or default to INFO
    ///
    /// - Returns: The log level
    public static func getLogLevel() -> Logger.Level {
        guard let levelStr = ProcessInfo.processInfo.environment["LOG_LEVEL"]?.uppercased() else {
            return .info
        }
        
        switch levelStr {
        case "TRACE":
            return .trace
        case "DEBUG":
            return .debug
        case "INFO":
            return .info
        case "NOTICE":
            return .notice
        case "WARNING", "WARN":
            return .warning
        case "ERROR":
            return .error
        case "CRITICAL", "FATAL":
            return .critical
        default:
            return .info
        }
    }
}

/// Custom file log handler
struct FileLogHandler: LogHandler {
    let label: String
    let fileHandle: FileHandle
    var logLevel: Logger.Level
    var metadata: Logger.Metadata = [:]
    
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
    
    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        let levelStr = level.rawValue.uppercased()
        
        var logLine = "[\(timestamp)] [\(levelStr)] [\(label)] \(message)"
        
        // Add metadata if present
        let allMetadata = self.metadata.merging(metadata ?? [:]) { $1 }
        if !allMetadata.isEmpty {
            let context = allMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logLine += " [\(context)]"
        }
        
        logLine += "\n"
        
        if let data = logLine.data(using: .utf8) {
            fileHandle.write(data)
        }
    }
}

/// Date formatter extensions
extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
