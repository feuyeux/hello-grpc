import Foundation
import GRPCCore

// NOTE on gzip compression: grpc-swift 2.x (GRPCCore / GRPCNIOTransportHTTP2,
// currently pinned per AGENTS.md) does not expose a message-compression
// configuration hook on HTTP2ClientTransport.Posix.Config as of this
// writing, unlike Go/Python/Java/C++/C#/Node/TS/PHP/Rust in this repo which
// all enable gzip at the channel level. There is nothing to wire up here
// until grpc-swift adds that support; tracked as a known parity gap rather
// than implemented with a nonexistent API.

/// A6 client-retry parameters for hello.LandingService, mirroring the
/// grpc.service_config retryPolicy used by the other language clients:
/// https://github.com/grpc/proposal/blob/master/A6-client-retries.md
///
/// grpc-swift 2.x has no built-in service-config/retryPolicy support, so
/// this is applied at the application level around unary calls instead of
/// via transport configuration.
public enum Retry {
    public static let maxAttempts = 4
    public static let initialBackoffSeconds = 0.1
    public static let maxBackoffSeconds = 1.0
    public static let backoffMultiplier = 2.0

    /// Returns true when `code` matches the retryableStatusCodes used by the
    /// shared A6 retry policy (`UNAVAILABLE` only).
    private static func isRetryable(_ code: RPCError.Code) -> Bool {
        code == .unavailable
    }

    /// Runs `operation` up to `maxAttempts` times, retrying only on
    /// `UNAVAILABLE` with exponential backoff (initial 0.1s, multiplier 2.0,
    /// capped at 1s) — the same policy encoded in the other languages'
    /// `retryPolicy` service config for `hello.LandingService`.
    public static func call<T: Sendable>(
        method: String,
        logger: Logger,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var backoff = initialBackoffSeconds
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                let rpcCode = (error as? RPCError)?.code
                let retryable = rpcCode.map(isRetryable) ?? false
                if attempt == maxAttempts || !retryable {
                    throw error
                }
                logger.warning(
                    "\(method) attempt \(attempt)/\(maxAttempts) failed with \(String(describing: rpcCode)), retrying in \(backoff)s"
                )
                try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                backoff = min(backoff * backoffMultiplier, maxBackoffSeconds)
            }
        }
        throw lastError ?? RPCError(code: .unavailable, message: "retry loop exhausted")
    }
}
