package org.feuyeux.grpc.common;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import lombok.extern.slf4j.Slf4j;

/** Manages graceful shutdown of the application */
@Slf4j
public class ShutdownHandler {

  private static final Duration DEFAULT_SHUTDOWN_TIMEOUT = Duration.ofSeconds(30);

  private final Duration timeout;
  private final List<AutoCloseable> cleanupFunctions;
  private final CountDownLatch shutdownLatch;
  private final ExecutorService shutdownExecutor;
  private volatile boolean shutdownInitiated = false;

  public ShutdownHandler() {
    this(DEFAULT_SHUTDOWN_TIMEOUT);
  }

  public ShutdownHandler(Duration timeout) {
    this.timeout = timeout;
    this.cleanupFunctions = Collections.synchronizedList(new ArrayList<>());
    this.shutdownLatch = new CountDownLatch(1);
    this.shutdownExecutor = Executors.newSingleThreadExecutor();

    // Register shutdown hook
    Runtime.getRuntime().addShutdownHook(new Thread(this::initiateShutdown));
  }

  /**
   * Registers cleanup function to be called during shutdown
   *
   * @param cleanup The cleanup function
   */
  public void registerCleanup(AutoCloseable cleanup) {
    cleanupFunctions.add(cleanup);
  }

  /**
   * Registers a runnable cleanup function
   *
   * @param cleanup The cleanup runnable
   */
  public void registerCleanup(Runnable cleanup) {
    cleanupFunctions.add(() -> cleanup.run());
  }

  /** Initiates the shutdown process */
  private void initiateShutdown() {
    if (shutdownInitiated) {
      return;
    }
    shutdownInitiated = true;
    shutdownLatch.countDown();
  }

  /** Waits for a shutdown signal */
  public void await() throws InterruptedException {
    shutdownLatch.await();
  }

  /**
   * Performs graceful shutdown with timeout
   *
   * @return true if shutdown completed successfully, false if timeout occurred
   */
  public boolean shutdown() {
    log.info("Starting graceful shutdown...");

    try {
      // Execute cleanup functions in reverse order (LIFO)
      List<AutoCloseable> reversedCleanup = new ArrayList<>(cleanupFunctions);
      Collections.reverse(reversedCleanup);

      boolean hasErrors = false;
      for (AutoCloseable cleanup : reversedCleanup) {
        try {
          cleanup.close();
        } catch (Exception e) {
          log.error("Error during cleanup: {}", e.getMessage(), e);
          hasErrors = true;
        }
      }

      // Shutdown the executor
      shutdownExecutor.shutdown();
      if (!shutdownExecutor.awaitTermination(timeout.toMillis(), TimeUnit.MILLISECONDS)) {
        log.warn("Shutdown timeout exceeded, forcing shutdown");
        shutdownExecutor.shutdownNow();
        return false;
      }

      if (hasErrors) {
        log.warn("Shutdown completed with errors");
      } else {
        log.info("Graceful shutdown completed successfully");
      }
      return true;

    } catch (InterruptedException e) {
      log.warn("Shutdown interrupted, forcing shutdown");
      shutdownExecutor.shutdownNow();
      Thread.currentThread().interrupt();
      return false;
    }
  }

  /**
   * Waits for a shutdown signal and then performs shutdown
   *
   * @return true if shutdown completed successfully, false if timeout occurred
   */
  public boolean awaitAndShutdown() throws InterruptedException {
    await();
    return shutdown();
  }
}
