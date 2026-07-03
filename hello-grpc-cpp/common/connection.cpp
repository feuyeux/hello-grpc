/**
 * @file connection.cpp
 * @brief Implementation of connection management for gRPC client
 */

#include "connection.h"

#include <cstdlib>
#include <fstream>
#include <string>

#include "glog/logging.h"
#include "grpcpp/grpcpp.h"

#include "utils.h"

namespace hello
{

  std::string Connection::getFileContent(const char *path)
  {
    std::ifstream stream(path);
    if (!stream.is_open())
    {
      LOG(ERROR) << "Failed to open file: " << path;
      return "";
    }

    std::string contents;
    contents.assign((std::istreambuf_iterator<char>(stream)),
                    std::istreambuf_iterator<char>());
    stream.close();

    return contents;
  }

  std::shared_ptr<grpc::Channel> Connection::getChannel()
  {
    // Certificate paths for TLS. CERT_BASE_PATH (directory containing the
    // client certificates) takes precedence over the platform default.
    std::string cert_base = "/var/hello_grpc/client_certs";
    if (const char *env_base = std::getenv("CERT_BASE_PATH"))
    {
      if (env_base[0] != '\0')
      {
        cert_base = env_base;
      }
    }
    const std::string cert = cert_base + "/cert.pem";
    const std::string cert_key = cert_base + "/private.key";
    const std::string cert_chain = cert_base + "/full_chain.pem";
    const std::string root_cert = cert_base + "/myssl_root.cer";
    const std::string server_name = "hello.grpc.io";

    const std::string &port = Utils::getBackendPort();
    const std::string target = Utils::getBackend() + ":" + port;
    const std::string &secure = Utils::getSecure();

    if (!secure.empty() && secure == "Y")
    {
      // Create secure channel with TLS
      grpc::SslCredentialsOptions ssl_opts;
      ssl_opts.pem_root_certs = Connection::getFileContent(root_cert.c_str());
      ssl_opts.pem_private_key = Connection::getFileContent(cert_key.c_str());
      ssl_opts.pem_cert_chain = Connection::getFileContent(cert.c_str());

      grpc::ChannelArguments channel_args;
      channel_args.SetString("grpc.default_authority", server_name);

      LOG(INFO) << "Connecting with TLS to " << target;
      return grpc::CreateCustomChannel(target, grpc::SslCredentials(ssl_opts),
                                       channel_args);
    }
    else
    {
      // Create insecure channel
      LOG(INFO) << "Connecting without TLS to " << target;
      return grpc::CreateChannel(target, grpc::InsecureChannelCredentials());
    }
  }

} // namespace hello
