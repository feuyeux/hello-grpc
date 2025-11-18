using System;
using System.IO;
using log4net;
using log4net.Appender;
using log4net.Core;
using log4net.Layout;
using log4net.Repository.Hierarchy;

namespace Common
{
    /// <summary>
    /// Logging configuration for standardized logging setup.
    /// Provides utilities to initialize logging with standard format:
    /// [TIMESTAMP] [LEVEL] [COMPONENT] MESSAGE [CONTEXT]
    /// </summary>
    public static class LoggingConfig
    {
        private const string DefaultLogDir = "logs";
        private const string TimestampFormat = "yyyy-MM-dd HH:mm:ss.fff";
        private const string LogPattern = "[%date{yyyy-MM-dd HH:mm:ss.fff}] [%level] [%logger] %message%newline";

        /// <summary>
        /// Initialize logging for a component with dual output (console and file)
        /// </summary>
        /// <param name="component">The component name (e.g., "client", "server")</param>
        /// <param name="logDir">The directory for log files (default: "logs")</param>
        /// <returns>Logger instance for the component</returns>
        public static ILog InitializeLogging(string component, string logDir = DefaultLogDir)
        {
            // Create log directory
            Directory.CreateDirectory(logDir);

            // Get the repository
            var repository = LogManager.GetRepository() as Hierarchy;
            if (repository == null)
            {
                throw new InvalidOperationException("Failed to get log4net repository");
            }

            // Create pattern layout
            var patternLayout = new PatternLayout
            {
                ConversionPattern = LogPattern
            };
            patternLayout.ActivateOptions();

            // Create console appender
            var consoleAppender = new ConsoleAppender
            {
                Layout = patternLayout,
                Threshold = GetLogLevel()
            };
            consoleAppender.ActivateOptions();

            // Create file appender with timestamp
            var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            var logFileName = Path.Combine(logDir, $"{component}_{timestamp}.log");
            
            var fileAppender = new RollingFileAppender
            {
                File = logFileName,
                AppendToFile = true,
                RollingStyle = RollingFileAppender.RollingMode.Size,
                MaxSizeRollBackups = 7,
                MaximumFileSize = "100MB",
                StaticLogFileName = true,
                Layout = patternLayout,
                Threshold = GetLogLevel()
            };
            fileAppender.ActivateOptions();

            // Configure repository
            repository.Root.Level = GetLogLevel();
            repository.Root.AddAppender(consoleAppender);
            repository.Root.AddAppender(fileAppender);
            repository.Configured = true;

            // Get logger
            var logger = LogManager.GetLogger(component);
            logger.Info($"Logging initialized for component: {component}");
            logger.Info($"Log file: {logFileName}");

            return logger;
        }

        /// <summary>
        /// Get log level from environment variable or default to INFO
        /// </summary>
        /// <returns>The log level</returns>
        private static Level GetLogLevel()
        {
            var levelStr = Environment.GetEnvironmentVariable("LOG_LEVEL");
            if (string.IsNullOrEmpty(levelStr))
            {
                return Level.Info;
            }

            return levelStr.ToUpper() switch
            {
                "DEBUG" => Level.Debug,
                "INFO" => Level.Info,
                "WARN" => Level.Warn,
                "WARNING" => Level.Warn,
                "ERROR" => Level.Error,
                "FATAL" => Level.Fatal,
                _ => Level.Info
            };
        }

        /// <summary>
        /// Shutdown logging and flush all appenders
        /// </summary>
        public static void ShutdownLogging()
        {
            LogManager.Shutdown();
        }
    }
}
