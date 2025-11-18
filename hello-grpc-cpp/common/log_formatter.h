#ifndef HELLO_GRPC_LOG_FORMATTER_H
#define HELLO_GRPC_LOG_FORMATTER_H

#include <chrono>
#include <string>
#include "grpcpp/grpcpp.h"
#include "glog/logging.h"

namespace hello {

const std::string SERVICE_NAME = "cpp";

/**
 * @brief Extract request ID from metadata
 */
inline std::string extractRequestId(grpc::ServerContext* context) {
    const auto& metadata = context->client_metadata();
    
    // Try multiple request ID header variants
    auto it = metadata.find("x-request-id");
    if (it != metadata.end()) {
        return std::string(it->second.data(), it->second.size());
    }
    
    it = metadata.find("request-id");
    if (it != metadata.end()) {
        return std::string(it->second.data(), it->second.size());
    }
    
    return "unknown";
}

/**
 * @brief Extract peer address from context
 */
inline std::string extractPeer(grpc::ServerContext* context) {
    std::string peer = context->peer();
    return peer.empty() ? "unknown" : peer;
}

/**
 * @brief Check if connection is secure
 */
inline bool isSecure() {
    const char* secure_env = std::getenv("GRPC_HELLO_SECURE");
    return secure_env != nullptr && std::string(secure_env) == "Y";
}

/**
 * @brief Log request start
 */
inline void logRequestStart(const std::string& method, const std::string& requestId, 
                            const std::string& peer) {
    bool secure = isSecure();
    LOG(INFO) << "service=" << SERVICE_NAME 
              << " request_id=" << requestId 
              << " method=" << method 
              << " peer=" << peer 
              << " secure=" << (secure ? "true" : "false")
              << " status=STARTED";
}

/**
 * @brief Log request end
 */
inline void logRequestEnd(const std::string& method, const std::string& requestId,
                         const std::string& peer, 
                         std::chrono::steady_clock::time_point startTime,
                         const std::string& status = "OK") {
    bool secure = isSecure();
    auto durationMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - startTime).count();
    
    LOG(INFO) << "service=" << SERVICE_NAME 
              << " request_id=" << requestId 
              << " method=" << method 
              << " peer=" << peer 
              << " secure=" << (secure ? "true" : "false")
              << " duration_ms=" << durationMs 
              << " status=" << status;
}

/**
 * @brief Log request error
 */
inline void logRequestError(const std::string& method, const std::string& requestId,
                           const std::string& peer,
                           std::chrono::steady_clock::time_point startTime,
                           const grpc::Status& status) {
    bool secure = isSecure();
    auto durationMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - startTime).count();
    
    LOG(ERROR) << "service=" << SERVICE_NAME 
               << " request_id=" << requestId 
               << " method=" << method 
               << " peer=" << peer 
               << " secure=" << (secure ? "true" : "false")
               << " duration_ms=" << durationMs 
               << " status=" << status.error_code()
               << " error_code=" << status.error_code()
               << " message=" << status.error_message();
}

} // namespace hello

#endif // HELLO_GRPC_LOG_FORMATTER_H
