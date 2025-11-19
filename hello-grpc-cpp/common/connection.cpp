/**
 * @file connection.cpp
 * @brief Implementation of connection management for gRPC client
 */

#include "connection.h"

#include <fstream>
#include <string>

#include "glog/logging.h"
#include "grpcpp/grpcpp.h"

#include "utils.h"

namespace hello {

std::string Connection::getFileContent(const char *path) {
  std::ifstream stream(path);
  if (!stream.is_open()) {
    LOG(ERROR) << "Failed to open file: " << path;
    return "";
  }

  std::string contents;
  contents.assign((std::istreambuf_iterator<char>(stream)),
                  std::istreambuf_iterator<char>());
  stream.close();

  return contents;
}

std::shared_ptr<grpc::Channel> Connection::getChannel() {
  // Certificate paths for TLS
  const char cert[] = "/var/hello_grpc/client_certs/cert.pem";
  const char cert_key[] = "/var/hello_grpc/client_certs/private.key";
  const char cert_chain[] = "/var/hello_grpc/client_certs/full_chain.pem";
  const char root_cert[] = "/var/hello_grpc/client_certs/myssl_root.cer";
  const std::string server_name = "hello.grpc.io";

  const std::string &port = Utils::getBackendPort();
  const std::string target = Utils::getBackend() + ":" + port;
  const std::string &secure = Utils::getSecure();

  if (!secure.empty() && secure == "Y") {
    // Create secure channel with TLS
    grpc::SslCredentialsOptions ssl_opts;
    ssl_opts.pem_root_certs = Connection::getFileContent(root_cert);
    ssl_opts.pem_private_key = Connection::getFileContent(cert_key);
    ssl_opts.pem_cert_chain = Connection::getFileContent(cert);

    grpc::ChannelArguments channel_args;
    channel_args.SetString("grpc.default_authority", server_name);

    LOG(INFO) << "Connecting with TLS to " << target;
    return grpc::CreateCustomChannel(target, grpc::SslCredentials(ssl_opts),
                                     channel_args);
  } else {
    // Create insecure channel
    LOG(INFO) << "Connecting without TLS to " << target;
    return grpc::CreateChannel(target, grpc::InsecureChannelCredentials());
  }
}

} // namespace hello
