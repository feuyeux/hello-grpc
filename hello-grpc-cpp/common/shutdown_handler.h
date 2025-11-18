/**
 * @file shutdown_handler.h
 * @brief Manages graceful shutdown of the application
 */

#ifndef HELLO_GRPC_SHUTDOWN_HANDLER_H
#define HELLO_GRPC_SHUTDOWN_HANDLER_H

#include <atomic>
#include <chrono>
#include <csignal>
#include <functional>
#include <mutex>
#include <vector>

#include <glog/logging.h>

namespace hello {

/**
 * @brief Manages graceful shutdown with signal handling and cleanup functions
 */
class ShutdownHandler {
public:
  using CleanupFunction = std::function<void()>;
  static constexpr std::chrono::seconds DEFAULT_SHUTDOWN_TIMEOUT{30};

  /**
   * @brief Constructs a shutdown handler with the specified timeout
   * @param timeout Timeout for graceful shutdown
   */
  explicit ShutdownHandler(std::chrono::seconds timeout = DEFAULT_SHUTDOWN_TIMEOUT)
      : timeout_(timeout), shutdown_initiated_(false) {
    registerSignalHandlers();
  }

  /**
   * @brief Registers a cleanup function to be called during shutdown
   * @param cleanup_fn The cleanup function
   */
  void registerCleanup(CleanupFunction cleanup_fn) {
    std::lock_guard<std::mutex> lock(mutex_);
    cleanup_functions_.push_back(std::move(cleanup_fn));
  }

  /**
   * @brief Initiates the shutdown process
   */
  void initiateShutdown() {
    bool expected = false;
    if (shutdown_initiated_.compare_exchange_strong(expected, true)) {
      LOG(INFO) << "Shutdown initiated";
    }
  }

  /**
   * @brief Checks if shutdown has been initiated
   * @return true if shutdown has been initiated, false otherwise
   */
  bool isShutdownInitiated() const {
    return shutdown_initiated_.load();
  }

  /**
   * @brief Waits for a shutdown signal
   */
  void wait() {
    while (!shutdown_initiated_.load()) {
      std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
  }

  /**
   * @brief Performs graceful shutdown with timeout
   * @return true if shutdown completed successfully, false if timeout occurred
   */
  bool shutdown() {
    LOG(INFO) << "Starting graceful shutdown...";

    auto start_time = std::chrono::steady_clock::now();
    bool has_errors = false;

    // Execute cleanup functions in reverse order (LIFO)
    std::lock_guard<std::mutex> lock(mutex_);
    for (auto it = cleanup_functions_.rbegin(); it != cleanup_functions_.rend(); ++it) {
      try {
        (*it)();
      } catch (const std::exception& e) {
        LOG(ERROR) << "Error during cleanup: " << e.what();
        has_errors = true;
      } catch (...) {
        LOG(ERROR) << "Unknown error during cleanup";
        has_errors = true;
      }

      // Check if we've exceeded the timeout
      auto elapsed = std::chrono::steady_clock::now() - start_time;
      if (elapsed > timeout_) {
        LOG(WARNING) << "Shutdown timeout exceeded, forcing shutdown";
        return false;
      }
    }

    if (has_errors) {
      LOG(WARNING) << "Shutdown completed with errors";
    } else {
      LOG(INFO) << "Graceful shutdown completed successfully";
    }

    return !has_errors;
  }

  /**
   * @brief Waits for a shutdown signal and then performs shutdown
   * @return true if shutdown completed successfully, false if timeout occurred
   */
  bool waitAndShutdown() {
    wait();
    return shutdown();
  }

  /**
   * @brief Gets the singleton instance of the shutdown handler
   * @return Reference to the singleton instance
   */
  static ShutdownHandler& getInstance() {
    static ShutdownHandler instance;
    return instance;
  }

private:
  std::chrono::seconds timeout_;
  std::atomic<bool> shutdown_initiated_;
  std::vector<CleanupFunction> cleanup_functions_;
  std::mutex mutex_;

  /**
   * @brief Registers signal handlers for SIGINT and SIGTERM
   */
  void registerSignalHandlers() {
    std::signal(SIGINT, signalHandler);
    std::signal(SIGTERM, signalHandler);
  }

  /**
   * @brief Static signal handler function
   * @param signal The signal number
   */
  static void signalHandler(int signal) {
    const char* signal_name = (signal == SIGINT) ? "SIGINT" : "SIGTERM";
    LOG(INFO) << "Received " << signal_name << " signal";
    getInstance().initiateShutdown();
  }
};

} // namespace hello

#endif // HELLO_GRPC_SHUTDOWN_HANDLER_H
