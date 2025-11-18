using System;
using System.Diagnostics;
using System.Linq;
using Grpc.Core;
using log4net;

namespace Common
{
    /// <summary>
    /// Unified log formatter for gRPC services.
    /// Provides consistent logging format across all RPC methods with standard fields:
    /// service, request_id, method, peer, secure, duration_ms, status
    /// </summary>
    public static class LogFormatter
    {
        private const string ServiceName = "csharp";
        private static readonly bool IsSecure = Environment.GetEnvironmentVariable("GRPC_HELLO_SECURE") == "Y";

        /// <summary>
        /// Extract request ID from metadata
        /// </summary>
        public static string ExtractRequestId(Metadata headers)
        {
            // Try multiple request ID header variants
            var entry = headers.FirstOrDefault(e => 
                e.Key == "x-request-id" || e.Key == "request-id");
            return entry?.Value ?? "unknown";
        }

        /// <summary>
        /// Extract peer address from context
        /// </summary>
        public static string ExtractPeer(ServerCallContext context)
        {
            return context.Peer ?? "unknown";
        }

        /// <summary>
        /// Check if connection is secure
        /// </summary>
        public static bool CheckSecure(ServerCallContext context)
        {
            return context.AuthContext?.IsPeerAuthenticated ?? IsSecure;
        }

        /// <summary>
        /// Log request start
        /// </summary>
        public static (string requestId, string peer, bool secure, Stopwatch stopwatch) LogRequestStart(
            ILog logger, string method, ServerCallContext context)
        {
            var requestId = ExtractRequestId(context.RequestHeaders);
            var peer = ExtractPeer(context);
            var secure = CheckSecure(context);
            var stopwatch = Stopwatch.StartNew();

            logger.Info($"service={ServiceName} request_id={requestId} method={method} " +
                       $"peer={peer} secure={secure} status=STARTED");

            return (requestId, peer, secure, stopwatch);
        }

        /// <summary>
        /// Log request end
        /// </summary>
        public static void LogRequestEnd(ILog logger, string method, string requestId, 
                                        string peer, bool secure, Stopwatch stopwatch, 
                                        string status = "OK")
        {
            stopwatch.Stop();
            var durationMs = stopwatch.ElapsedMilliseconds;

            logger.Info($"service={ServiceName} request_id={requestId} method={method} " +
                       $"peer={peer} secure={secure} duration_ms={durationMs} status={status}");
        }

        /// <summary>
        /// Log request error
        /// </summary>
        public static void LogRequestError(ILog logger, string method, string requestId,
                                          string peer, bool secure, Stopwatch stopwatch,
                                          StatusCode statusCode, string errorCode, string message,
                                          Exception exception = null)
        {
            stopwatch.Stop();
            var durationMs = stopwatch.ElapsedMilliseconds;

            if (exception != null)
            {
                logger.Error($"service={ServiceName} request_id={requestId} method={method} " +
                           $"peer={peer} secure={secure} duration_ms={durationMs} " +
                           $"status={statusCode} error_code={errorCode} message={message}", exception);
            }
            else
            {
                logger.Error($"service={ServiceName} request_id={requestId} method={method} " +
                           $"peer={peer} secure={secure} duration_ms={durationMs} " +
                           $"status={statusCode} error_code={errorCode} message={message}");
            }
        }
    }
}
