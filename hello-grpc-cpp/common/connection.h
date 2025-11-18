/**
 * @file connection.h
 * @brief Connection management for gRPC client
 */

#ifndef HELLO_GRPC_CONNECTION_H
#define HELLO_GRPC_CONNECTION_H

#include <memory>
#include <string>

#include "grpcpp/grpcpp.h"

namespace hello {

/**
 * @brief Connection management class for gRPC client
 */
class Connection {
public:
  /**
   * @brief Reads the content of a file
   * @param path Path to the file
   * @return File content as string
   */
  static std::string getFileContent(const char *path);

  /**
   * @brief Creates a gRPC channel with appropriate credentials
   * @return Shared pointer to gRPC channel
   */
  static std::shared_ptr<grpc::Channel> getChannel();
};

} // namespace hello

#endif // HELLO_GRPC_CONNECTION_H
