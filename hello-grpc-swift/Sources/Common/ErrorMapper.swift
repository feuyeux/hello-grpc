import Foundation
import GRPCCore

/// Maps gRPC RPCError status codes to human-readable messages.
///
/// Mirrors the ErrorMapper pattern used across the other hello-grpc language
/// implementations (PHP, Java, Kotlin, C#).
public enum ErrorMapper {

    /// Returns a human-readable description of a gRPC error.
    ///
    /// If `error` is an `RPCError` the status code is mapped to a fixed
    /// English description.  For any other `Error` the localised description
    /// is returned unchanged.
    public static func mapGrpcError(_ error: Error) -> String {
        guard let rpcError = error as? RPCError else {
            return error.localizedDescription
        }

        let description = statusDescription(for: rpcError.code)
        let message = rpcError.message
        if message.isEmpty {
            return description
        }
        return "\(description): \(message)"
    }

    // MARK: - Private helpers

    private static func statusDescription(for code: RPCError.Code) -> String {
        switch code {
        case .ok:                  return "Success"
        case .cancelled:           return "Operation cancelled"
        case .unknown:             return "Unknown error"
        case .invalidArgument:     return "Invalid request parameters"
        case .deadlineExceeded:    return "Request timeout"
        case .notFound:            return "Resource not found"
        case .alreadyExists:       return "Resource already exists"
        case .permissionDenied:    return "Permission denied"
        case .resourceExhausted:   return "Resource exhausted"
        case .failedPrecondition:  return "Precondition failed"
        case .aborted:             return "Operation aborted"
        case .outOfRange:          return "Out of range"
        case .unimplemented:       return "Not implemented"
        case .internalError:       return "Internal server error"
        case .unavailable:         return "Service unavailable"
        case .dataLoss:            return "Data loss"
        case .unauthenticated:     return "Authentication required"
        default:                   return "Unknown error code"
        }
    }
}
