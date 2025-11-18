import Foundation
import GRPC

/// Unified error mapper for converting Swift errors to gRPC status codes.
///
/// This module provides consistent error handling across the gRPC service by mapping
/// common application errors to appropriate gRPC status codes according to the
/// unified error handling strategy.
///
/// Error Mapping Rules:
/// - Input Validation Failed → INVALID_ARGUMENT
/// - Request Timeout → DEADLINE_EXCEEDED
/// - Backend Unreachable → UNAVAILABLE
/// - Authentication Failed → UNAUTHENTICATED
/// - Permission Denied → PERMISSION_DENIED
/// - Resource Not Found → NOT_FOUND
/// - Resource Already Exists → ALREADY_EXISTS
/// - Internal Server Error → INTERNAL
public enum ErrorMapper {
    
    /// Maps a Swift error to an appropriate gRPC status code.
    ///
    /// - Parameters:
    ///   - error: The error to map
    ///   - requestId: The request ID for logging context
    /// - Returns: The appropriate gRPC status code
    public static func mapToStatusCode(_ error: Error, requestId: String = "") -> GRPCStatus.Code {
        // Already a gRPC error - preserve it
        if let grpcError = error as? GRPCStatus {
            return grpcError.code
        }
        
        // Check for specific error types
        let nsError = error as NSError
        let errorMessage = error.localizedDescription.lowercased()
        
        // URL/Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .deadlineExceeded
            case NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet:
                return .unavailable
            default:
                return .internal
            }
        }
        
        // POSIX errors
        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case Int(ENOENT):  // No such file or directory
                return .notFound
            case Int(EACCES):  // Permission denied
                return .permissionDenied
            case Int(EEXIST):  // File exists
                return .alreadyExists
            case Int(ETIMEDOUT):  // Connection timed out
                return .deadlineExceeded
            case Int(ECONNREFUSED):  // Connection refused
                return .unavailable
            default:
                return .internal
            }
        }
        
        // Check error message for common patterns
        if errorMessage.contains("invalid") ||
           errorMessage.contains("validation") ||
           errorMessage.contains("bad request") {
            return .invalidArgument
        }
        
        if errorMessage.contains("timeout") ||
           errorMessage.contains("deadline") {
            return .deadlineExceeded
        }
        
        if errorMessage.contains("authentication") ||
           errorMessage.contains("unauthorized") ||
           errorMessage.contains("unauthenticated") {
            return .unauthenticated
        }
        
        if errorMessage.contains("permission") ||
           errorMessage.contains("forbidden") ||
           errorMessage.contains("access denied") {
            return .permissionDenied
        }
        
        if errorMessage.contains("not found") ||
           errorMessage.contains("no such") {
            return .notFound
        }
        
        if errorMessage.contains("already exists") ||
           errorMessage.contains("duplicate") {
            return .alreadyExists
        }
        
        if errorMessage.contains("unavailable") ||
           errorMessage.contains("unreachable") ||
           errorMessage.contains("connection refused") {
            return .unavailable
        }
        
        // Default to INTERNAL for unknown errors
        return .internal
    }
    
    /// Converts a Swift error to a gRPC Status.
    ///
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - requestId: The request ID for logging context
    /// - Returns: A gRPC Status with mapped code and message
    public static func toGRPCStatus(_ error: Error, requestId: String = "") -> GRPCStatus {
        let code = mapToStatusCode(error, requestId: requestId)
        var message = getErrorMessage(error)
        
        // Add request ID to error details if available
        if !requestId.isEmpty {
            message = "[request_id=\(requestId)] \(message)"
        }
        
        return GRPCStatus(code: code, message: message)
    }
    
    /// Gets a formatted error message from an error.
    ///
    /// - Parameter error: The error to format
    /// - Returns: A formatted error message
    public static func getErrorMessage(_ error: Error) -> String {
        if let grpcError = error as? GRPCStatus {
            return grpcError.message ?? grpcError.code.description
        }
        
        return error.localizedDescription
    }
    
    /// Gets a human-readable error code for logging purposes.
    ///
    /// - Parameter error: The error to get code for
    /// - Returns: The error code name
    public static func getErrorCode(_ error: Error) -> String {
        let code = mapToStatusCode(error)
        return "\(code)"
    }
    
    /// Wraps a throwing closure with unified error handling.
    ///
    /// - Parameters:
    ///   - requestId: The request ID for logging context
    ///   - closure: The closure to execute
    /// - Returns: The result of the closure
    /// - Throws: A GRPCStatus error with mapped code
    public static func wrap<T>(requestId: String = "", _ closure: () throws -> T) throws -> T {
        do {
            return try closure()
        } catch {
            throw toGRPCStatus(error, requestId: requestId)
        }
    }
    
    /// Wraps an async throwing closure with unified error handling.
    ///
    /// - Parameters:
    ///   - requestId: The request ID for logging context
    ///   - closure: The async closure to execute
    /// - Returns: The result of the closure
    /// - Throws: A GRPCStatus error with mapped code
    public static func wrapAsync<T>(requestId: String = "", _ closure: () async throws -> T) async throws -> T {
        do {
            return try await closure()
        } catch {
            throw toGRPCStatus(error, requestId: requestId)
        }
    }
}
