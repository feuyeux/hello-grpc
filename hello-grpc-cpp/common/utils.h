/**
 * @file utils.h
 * @brief Utility functions for gRPC client and server
 */

#ifndef HELLO_GRPC_UTILS_H
#define HELLO_GRPC_UTILS_H

#include <list>
#include <string>

#include "protos/landing.grpc.pb.h"

using hello::TalkRequest;

namespace hello {

/**
 * @brief Utility class providing common helper functions
 */
class Utils {
public:
  /**
   * @brief Gets a greeting in the specified language
   * @param index Language index (0-5)
   * @return Greeting string
   */
  static std::string hello(int index);

  /**
   * @brief Generates a UUID string
   * @return UUID string
   */
  static std::string uuid();

  /**
   * @brief Gets a thank you message for the given greeting
   * @param key The greeting to respond to
   * @return Thank you message
   */
  static std::string thanks(std::string key);

  /**
   * @brief Builds a list of TalkRequest objects for streaming
   * @return List of TalkRequest objects
   */
  static std::list<TalkRequest> buildLinkRequests();

  /**
   * @brief Initializes logging configuration
   * @param argv Command line arguments
   */
  static void initLog(char *const *argv);

  /**
   * @brief Generates a random number between 0 and n
   * @param n Upper bound (inclusive)
   * @return Random number
   */
  static int random(int n);

  /**
   * @brief Gets current timestamp in nanoseconds
   * @return Current timestamp
   */
  static long now();

  /**
   * @brief Gets the server host from environment or default
   * @return Server host string
   */
  static std::string getServerHost();

  /**
   * @brief Gets the server port from environment or default
   * @return Server port string
   */
  static std::string getServerPort();

  /**
   * @brief Gets the backend host from environment or default
   * @return Backend host string
   */
  static std::string getBackend();

  /**
   * @brief Gets the backend port from environment or default
   * @return Backend port string
   */
  static std::string getBackendPort();

  /**
   * @brief Gets the secure mode flag from environment
   * @return "Y" if TLS enabled, empty otherwise
   */
  static std::string getSecure();

  /**
   * @brief Gets the gRPC version string
   * @return Version string
   */
  static std::string getVersion();
};

} // namespace hello

#endif // HELLO_GRPC_UTILS_H
