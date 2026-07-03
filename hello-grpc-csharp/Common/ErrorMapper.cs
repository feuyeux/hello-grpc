using System;
using System.Collections.Generic;
using Grpc.Core;
using log4net;

namespace Common
{
    /// <summary>
    /// Error mapper for translating gRPC status codes to human-readable messages
    /// and determining whether an error is retryable.
    /// </summary>
    public static class ErrorMapper
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(ErrorMapper));

        /// <summary>
        /// Maps gRPC RpcException to human-readable error message
        /// </summary>
        /// <param name="exception">The exception to map</param>
        /// <returns>Human-readable error message</returns>
        public static string MapGrpcError(Exception exception)
        {
            if (exception == null)
            {
                return "Success";
            }

            if (exception is RpcException rpcException)
            {
                string description = GetStatusDescription(rpcException.StatusCode);
                string message = rpcException.Status.Detail;

                if (!string.IsNullOrEmpty(message))
                {
                    return $"{description}: {message}";
                }
                return description;
            }

            return $"Unknown error: {exception.Message}";
        }

        /// <summary>
        /// Gets human-readable description for a gRPC status code
        /// </summary>
        /// <param name="code">The status code</param>
        /// <returns>Human-readable description</returns>
        private static string GetStatusDescription(StatusCode code)
        {
            return code switch
            {
                StatusCode.OK => "Success",
                StatusCode.Cancelled => "Operation cancelled",
                StatusCode.Unknown => "Unknown error",
                StatusCode.InvalidArgument => "Invalid request parameters",
                StatusCode.DeadlineExceeded => "Request timeout",
                StatusCode.NotFound => "Resource not found",
                StatusCode.AlreadyExists => "Resource already exists",
                StatusCode.PermissionDenied => "Permission denied",
                StatusCode.ResourceExhausted => "Resource exhausted",
                StatusCode.FailedPrecondition => "Precondition failed",
                StatusCode.Aborted => "Operation aborted",
                StatusCode.OutOfRange => "Out of range",
                StatusCode.Unimplemented => "Not implemented",
                StatusCode.Internal => "Internal server error",
                StatusCode.Unavailable => "Service unavailable",
                StatusCode.DataLoss => "Data loss",
                StatusCode.Unauthenticated => "Authentication required",
                _ => "Unknown error code"
            };
        }

        /// <summary>
        /// Determines if an error should be retried
        /// </summary>
        /// <param name="exception">The exception to check</param>
        /// <returns>true if the error is retryable, false otherwise</returns>
        public static bool IsRetryableError(Exception exception)
        {
            if (exception == null)
            {
                return false;
            }

            if (exception is not RpcException rpcException)
            {
                return false;
            }

            return rpcException.StatusCode switch
            {
                StatusCode.Unavailable or 
                StatusCode.DeadlineExceeded or 
                StatusCode.ResourceExhausted or 
                StatusCode.Internal => true,
                _ => false
            };
        }

        /// <summary>
        /// Logs an error with request ID and operation context
        /// </summary>
        /// <param name="exception">The exception that occurred</param>
        /// <param name="requestId">The request ID</param>
        /// <param name="operation">The operation name</param>
        public static void LogError(Exception exception, string requestId, string operation)
        {
            if (exception == null)
            {
                return;
            }

            string errorMsg = MapGrpcError(exception);
            Log.Error($"[{operation}] Request {requestId} failed: {errorMsg}");
        }

        /// <summary>
        /// Handles RPC errors with logging and context
        /// </summary>
        /// <param name="exception">The exception that occurred</param>
        /// <param name="operation">The operation name</param>
        /// <param name="context">Additional context information</param>
        public static void HandleRpcError(Exception exception, string operation, Dictionary<string, object> context = null)
        {
            if (exception == null)
            {
                return;
            }

            string errorMsg = MapGrpcError(exception);
            var logContext = new Dictionary<string, object>(context ?? new Dictionary<string, object>())
            {
                ["operation"] = operation,
                ["error"] = errorMsg
            };

            string contextStr = string.Join(", ", logContext);

            if (IsRetryableError(exception))
            {
                Log.Warn($"Retryable error occurred: {contextStr}");
            }
            else
            {
                Log.Error($"Non-retryable error occurred: {contextStr}");
            }
        }
    }
}
