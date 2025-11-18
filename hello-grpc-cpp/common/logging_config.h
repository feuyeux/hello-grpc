#ifndef HELLO_GRPC_LOGGING_CONFIG_H
#define HELLO_GRPC_LOGGING_CONFIG_H

#include <memory>
#include <string>
#include <filesystem>
#include <chrono>
#include <iomanip>
#include <sstream>
#include "glog/logging.h"

namespace hello {

/**
 * @brief Logging configuration for standardized logging setup
 * 
 * Provides utilities to initialize logging with standard format:
 * [TIMESTAMP] [LEVEL] [COMPONENT] MESSAGE [CONTEXT]
 * 
 * Uses Google's glog library with dual output (console and file).
 */
class LoggingConfig {
public:
    /**
     * @brief Initialize logging for a component
     * 
     * Creates log directory if it doesn't exist and configures glog
     * for dual output (console and file).
     * 
     * @param component The component name (e.g., "client", "server")
     * @param logDir The directory for log files (default: "logs")
     */
    static void initializeLogging(const std::string& component, 
                                  const std::string& logDir = "logs") {
        // Create log directory
        std::filesystem::create_directories(logDir);
        
        // Initialize Google logging
        google::InitGoogleLogging(component.c_str());
        
        // Set log destination
        FLAGS_log_dir = logDir;
        
        // Log to both stderr and files
        FLAGS_alsologtostderr = true;
        
        // Set log file naming
        FLAGS_timestamp_in_logfile_name = true;
        
        // Set log level (0=INFO, 1=WARNING, 2=ERROR, 3=FATAL)
        FLAGS_minloglevel = getLogLevel();
        
        // Set log format
        FLAGS_logbufsecs = 0;  // Flush immediately
        FLAGS_max_log_size = 100;  // Max log file size in MB
        
        LOG(INFO) << "Logging initialized for component: " << component;
    }
    
    /**
     * @brief Get log level from environment variable
     * 
     * @return Log level (0=INFO, 1=WARNING, 2=ERROR, 3=FATAL)
     */
    static int getLogLevel() {
        const char* level = std::getenv("LOG_LEVEL");
        if (level == nullptr) {
            return 0;  // INFO
        }
        
        std::string levelStr(level);
        if (levelStr == "DEBUG" || levelStr == "INFO") {
            return 0;
        } else if (levelStr == "WARN" || levelStr == "WARNING") {
            return 1;
        } else if (levelStr == "ERROR") {
            return 2;
        } else if (levelStr == "FATAL") {
            return 3;
        }
        
        return 0;  // Default to INFO
    }
    
    /**
     * @brief Shutdown logging
     * 
     * Flushes and closes all log files.
     */
    static void shutdownLogging() {
        google::ShutdownGoogleLogging();
    }
    
    /**
     * @brief Get current timestamp in standard format
     * 
     * @return Timestamp string in format: YYYY-MM-DD HH:MM:SS.mmm
     */
    static std::string getTimestamp() {
        auto now = std::chrono::system_clock::now();
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            now.time_since_epoch()) % 1000;
        auto timer = std::chrono::system_clock::to_time_t(now);
        std::tm bt = *std::localtime(&timer);
        
        std::ostringstream oss;
        oss << std::put_time(&bt, "%Y-%m-%d %H:%M:%S");
        oss << '.' << std::setfill('0') << std::setw(3) << ms.count();
        
        return oss.str();
    }
};

} // namespace hello

#endif // HELLO_GRPC_LOGGING_CONFIG_H
