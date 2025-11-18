using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Grpc.Core;
using log4net;

namespace Common
{
    /// <summary>
    /// Configuration for retry logic
    /// </summary>
    public class RetryConfig
    {
        public int MaxRetries { get; set; }
        public TimeSpan InitialDelay { get; set; }
        public TimeSpan MaxDelay { get; set; }
        public double Multiplier { get; set; }

        /// <summary>
        /// Creates default retry configuration
        /// </summary>
        public static RetryConfig Default()
        {
            return new RetryConfig
            {
                MaxRetries = 3,
                InitialDelay = TimeSpan.FromSeconds(2),
                MaxDelay = TimeSpan.FromSeconds(30),
                Multiplier = 2.0
            };
        }
    }

    /// <summary>
    /// Error mapper for translating gRPC status codes to human-readable messages
    /// and implementing retry logic with exponential backoff.
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

        /// <summary>
        /// Executes a function with exponential backoff retry logic
        /// </summary>
        /// <typeparam name="T">The return type</typeparam>
        /// <param name="operation">The operation name for logging</param>
        /// <param name="func">The function to execute</param>
        /// <param name="config">The retry configuration</param>
        /// <param name="cancellationToken">Cancellation token</param>
        /// <returns>The result of the function</returns>
        public static async Task<T> RetryWithBackoffAsync<T>(
            string operation, 
            Func<Task<T>> func, 
            RetryConfig config = null,
            CancellationToken cancellationToken = default)
        {
            config ??= RetryConfig.Default();
            Exception lastException = null;
            TimeSpan delay = config.InitialDelay;

            for (int attempt = 0; attempt <= config.MaxRetries; attempt++)
            {
                if (attempt > 0)
                {
                    Log.Info($"Retry attempt {attempt}/{config.MaxRetries} for {operation} after {delay.TotalMilliseconds}ms");
                    
                    try
                    {
                        await Task.Delay(delay, cancellationToken);
                    }
                    catch (TaskCanceledException)
                    {
                        throw new OperationCanceledException("Operation cancelled");
                    }
                }

                try
                {
                    T result = await func();
                    if (attempt > 0)
                    {
                        Log.Info($"Operation {operation} succeeded after {attempt + 1} attempts");
                    }
                    return result;
                }
                catch (Exception ex)
                {
                    lastException = ex;

                    if (!IsRetryableError(ex))
                    {
                        Log.Warn($"Non-retryable error for {operation}: {MapGrpcError(ex)}");
                        throw;
                    }

                    if (attempt < config.MaxRetries)
                    {
                        // Calculate next delay with exponential backoff
                        delay = TimeSpan.FromMilliseconds(delay.TotalMilliseconds * config.Multiplier);
                        if (delay > config.MaxDelay)
                        {
                            delay = config.MaxDelay;
                        }
                    }
                }
            }

            Log.Error($"Operation {operation} failed after {config.MaxRetries + 1} attempts: {MapGrpcError(lastException)}");
            throw new Exception($"Max retries exceeded for {operation}", lastException);
        }

        /// <summary>
        /// Executes an action with exponential backoff retry logic
        /// </summary>
        /// <param name="operation">The operation name for logging</param>
        /// <param name="action">The action to execute</param>
        /// <param name="config">The retry configuration</param>
        /// <param name="cancellationToken">Cancellation token</param>
        public static async Task RetryWithBackoffAsync(
            string operation, 
            Func<Task> action, 
            RetryConfig config = null,
            CancellationToken cancellationToken = default)
        {
            await RetryWithBackoffAsync<object>(operation, async () =>
            {
                await action();
                return null;
            }, config, cancellationToken);
        }

        /// <summary>
        /// Executes a synchronous function with exponential backoff retry logic
        /// </summary>
        /// <typeparam name="T">The return type</typeparam>
        /// <param name="operation">The operation name for logging</param>
        /// <param name="func">The function to execute</param>
        /// <param name="config">The retry configuration</param>
        /// <returns>The result of the function</returns>
        public static T RetryWithBackoff<T>(string operation, Func<T> func, RetryConfig config = null)
        {
            config ??= RetryConfig.Default();
            Exception lastException = null;
            TimeSpan delay = config.InitialDelay;

            for (int attempt = 0; attempt <= config.MaxRetries; attempt++)
            {
                if (attempt > 0)
                {
                    Log.Info($"Retry attempt {attempt}/{config.MaxRetries} for {operation} after {delay.TotalMilliseconds}ms");
                    Thread.Sleep(delay);
                }

                try
                {
                    T result = func();
                    if (attempt > 0)
                    {
                        Log.Info($"Operation {operation} succeeded after {attempt + 1} attempts");
                    }
                    return result;
                }
                catch (Exception ex)
                {
                    lastException = ex;

                    if (!IsRetryableError(ex))
                    {
                        Log.Warn($"Non-retryable error for {operation}: {MapGrpcError(ex)}");
                        throw;
                    }

                    if (attempt < config.MaxRetries)
                    {
                        // Calculate next delay with exponential backoff
                        delay = TimeSpan.FromMilliseconds(delay.TotalMilliseconds * config.Multiplier);
                        if (delay > config.MaxDelay)
                        {
                            delay = config.MaxDelay;
                        }
                    }
                }
            }

            Log.Error($"Operation {operation} failed after {config.MaxRetries + 1} attempts: {MapGrpcError(lastException)}");
            throw new Exception($"Max retries exceeded for {operation}", lastException);
        }
    }
}
