using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using log4net;

namespace Common
{
    /// <summary>
    /// Manages graceful shutdown of the application
    /// </summary>
    public class ShutdownHandler
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(ShutdownHandler));
        private static readonly TimeSpan DefaultShutdownTimeout = TimeSpan.FromSeconds(30);

        private readonly TimeSpan _timeout;
        private readonly List<Func<Task>> _cleanupFunctions;
        private readonly CancellationTokenSource _shutdownCts;
        private bool _shutdownInitiated;
        private readonly object _lock = new object();

        public ShutdownHandler() : this(DefaultShutdownTimeout)
        {
        }

        public ShutdownHandler(TimeSpan timeout)
        {
            _timeout = timeout;
            _cleanupFunctions = new List<Func<Task>>();
            _shutdownCts = new CancellationTokenSource();
            _shutdownInitiated = false;

            RegisterSignalHandlers();
        }

        /// <summary>
        /// Gets the cancellation token for shutdown
        /// </summary>
        public CancellationToken ShutdownToken => _shutdownCts.Token;

        /// <summary>
        /// Registers a cleanup function to be called during shutdown
        /// </summary>
        /// <param name="cleanupFn">The cleanup function (can be async)</param>
        public void RegisterCleanup(Func<Task> cleanupFn)
        {
            lock (_lock)
            {
                _cleanupFunctions.Add(cleanupFn);
            }
        }

        /// <summary>
        /// Registers a synchronous cleanup function
        /// </summary>
        /// <param name="cleanupFn">The cleanup action</param>
        public void RegisterCleanup(Action cleanupFn)
        {
            lock (_lock)
            {
                _cleanupFunctions.Add(() =>
                {
                    cleanupFn();
                    return Task.CompletedTask;
                });
            }
        }

        /// <summary>
        /// Registers signal handlers for SIGINT and SIGTERM
        /// </summary>
        private void RegisterSignalHandlers()
        {
            Console.CancelKeyPress += (sender, e) =>
            {
                e.Cancel = true;
                Log.Info("Received SIGINT signal (Ctrl+C)");
                InitiateShutdown();
            };

            // For SIGTERM on Unix-like systems
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                AppDomain.CurrentDomain.ProcessExit += (sender, e) =>
                {
                    Log.Info("Received SIGTERM signal");
                    InitiateShutdown();
                };
            }
        }

        /// <summary>
        /// Initiates the shutdown process
        /// </summary>
        public void InitiateShutdown()
        {
            lock (_lock)
            {
                if (_shutdownInitiated)
                {
                    return;
                }
                _shutdownInitiated = true;
            }

            Log.Info("Shutdown initiated");
            _shutdownCts.Cancel();
        }

        /// <summary>
        /// Checks if shutdown has been initiated
        /// </summary>
        public bool IsShutdownInitiated
        {
            get
            {
                lock (_lock)
                {
                    return _shutdownInitiated;
                }
            }
        }

        /// <summary>
        /// Waits for a shutdown signal
        /// </summary>
        public async Task WaitAsync()
        {
            try
            {
                await Task.Delay(Timeout.Infinite, _shutdownCts.Token);
            }
            catch (TaskCanceledException)
            {
                // Expected when shutdown is initiated
            }
        }

        /// <summary>
        /// Performs graceful shutdown with timeout
        /// </summary>
        /// <returns>true if shutdown completed successfully, false if timeout occurred</returns>
        public async Task<bool> ShutdownAsync()
        {
            Log.Info("Starting graceful shutdown...");

            try
            {
                using var timeoutCts = new CancellationTokenSource(_timeout);
                bool hasErrors = false;

                // Execute cleanup functions in reverse order (LIFO)
                List<Func<Task>> cleanupCopy;
                lock (_lock)
                {
                    cleanupCopy = new List<Func<Task>>(_cleanupFunctions);
                }

                cleanupCopy.Reverse();

                foreach (var cleanupFn in cleanupCopy)
                {
                    try
                    {
                        await cleanupFn();
                    }
                    catch (Exception ex)
                    {
                        Log.Error($"Error during cleanup: {ex.Message}", ex);
                        hasErrors = true;
                    }

                    if (timeoutCts.Token.IsCancellationRequested)
                    {
                        Log.Warn("Shutdown timeout exceeded, forcing shutdown");
                        return false;
                    }
                }

                if (hasErrors)
                {
                    Log.Warn("Shutdown completed with errors");
                }
                else
                {
                    Log.Info("Graceful shutdown completed successfully");
                }

                return !hasErrors;
            }
            catch (Exception ex)
            {
                Log.Error($"Error during shutdown: {ex.Message}", ex);
                return false;
            }
        }

        /// <summary>
        /// Waits for a shutdown signal and then performs shutdown
        /// </summary>
        /// <returns>true if shutdown completed successfully, false if timeout occurred</returns>
        public async Task<bool> WaitAndShutdownAsync()
        {
            await WaitAsync();
            return await ShutdownAsync();
        }
    }
}
