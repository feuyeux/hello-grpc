package org.feuyeux.grpc.common;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Logging configuration helper for standardized logging setup.
 *
 * <p>Provides utilities to initialize logging with standard format: [TIMESTAMP] [LEVEL] [COMPONENT]
 * MESSAGE [CONTEXT]
 *
 * <p>Logging is configured via logback.xml with dual output (console and file).
 */
public class LoggingConfig {
  private static final String DEFAULT_LOG_DIR = "logs";
  private static final DateTimeFormatter TIMESTAMP_FORMAT =
      DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss");

  /**
   * Initialize logging for a component.
   *
   * <p>Creates log directory if it doesn't exist and sets system properties for logback
   * configuration.
   *
   * @param component The component name (e.g., "client", "server")
   * @return Logger instance for the component
   */
  public static Logger initializeLogging(String component) {
    return initializeLogging(component, DEFAULT_LOG_DIR);
  }

  /**
   * Initialize logging for a component with custom log directory.
   *
   * @param component The component name (e.g., "client", "server")
   * @param logDir The directory for log files
   * @return Logger instance for the component
   */
  public static Logger initializeLogging(String component, String logDir) {
    // Create log directory
    try {
      Path logPath = Paths.get(logDir);
      if (!Files.exists(logPath)) {
        Files.createDirectories(logPath);
      }
    } catch (IOException e) {
      System.err.println("Failed to create log directory: " + e.getMessage());
    }

    // Set system properties for logback
    System.setProperty("COMPONENT", component);
    String timestamp = LocalDateTime.now().format(TIMESTAMP_FORMAT);
    System.setProperty("bySecond", timestamp);

    // Get logger
    Logger logger = LoggerFactory.getLogger(component);
    logger.info("Logging initialized for component: {}", component);

    return logger;
  }

  /**
   * Get log level from environment variable or default to INFO.
   *
   * @return The log level string
   */
  public static String getLogLevel() {
    String level = System.getenv("LOG_LEVEL");
    return level != null ? level : "INFO";
  }
}
