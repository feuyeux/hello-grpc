#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <memory>
#include <regex>
#include <string>

#include "grpcpp/ext/proto_server_reflection_plugin.h"
#include "grpcpp/grpcpp.h"
#include "grpcpp/health_check_service_interface.h"

#include "protos/landing.grpc.pb.h"

#include "glog/logging.h"

#include "common/connection.h"
#include "common/utils.h"

namespace {
/**
 * @brief Get the base directory for certificates
 *
 * This function determines the certificate path based on:
 * 1. The CERT_BASE_PATH environment variable if set
 * 2. Platform-specific defaults otherwise
 *
 * @return std::string The base path for certificate files
 */
std::string getCertBasePath() {
  // Check for environment variable override first
  const char *envPath = std::getenv("CERT_BASE_PATH");
  if (envPath != nullptr) {
    return envPath;
  }

  // Otherwise use platform-specific defaults
#ifdef _WIN32
  return "C:\\var\\hello_grpc\\server_certs";
#elif __APPLE__
  return "/var/hello_grpc/server_certs";
#else
  return "/var/hello_grpc/server_certs";
#endif
}

// Certificate paths based on platform
const std::string certBasePath = getCertBasePath();
const std::string cert = certBasePath + "/cert.pem";
const std::string certKey = certBasePath + "/private.key";
const std::string certChain = certBasePath + "/full_chain.pem";
const std::string rootCert = certBasePath + "/myssl_root.cer";

// Tracing headers to propagate
const std::vector<std::string> TRACING_HEADERS = {
    "x-request-id", "x-b3-traceid", "x-b3-spanid",      "x-b3-parentspanid",
    "x-b3-sampled", "x-b3-flags",   "x-ot-span-context"};

} // namespace

using google::protobuf::Map;
using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::ServerReader;
using grpc::ServerReaderWriter;
using grpc::ServerWriter;
using grpc::Status;
using hello::Connection;
using hello::LandingService;
using hello::ResultType;
using hello::TalkRequest;
using hello::TalkResponse;
using hello::TalkResult;
using hello::Utils;

/**
 * @brief Implementation of the LandingService gRPC service
 *
 * This class implements the four types of gRPC communication patterns:
 * 1. Unary RPC (Talk)
 * 2. Server Streaming RPC (TalkOneAnswerMore)
 * 3. Client Streaming RPC (TalkMoreAnswerOne)
 * 4. Bidirectional Streaming RPC (TalkBidirectional)
 */
class LandingServiceImpl final : public LandingService::Service {
public:
  LandingServiceImpl() = default;

  /**
   * @brief Implements the unary RPC method
   */
  Status Talk(ServerContext *context, const TalkRequest *request,
              TalkResponse *response) override {
    if (client) {
      // Proxy mode - forward request to backend
      grpc::ClientContext c;
      propagateHeaders(context, c);
      LOG(INFO) << "Proxying unary request to backend";
      return client->Talk(&c, *request, response);
    } else {
      // Direct mode - handle locally
      logHeaders(context, "Talk");

      const auto &id = request->data();
      LOG(INFO) << "Unary call received - data: " << id
                << ", meta: " << request->meta();

      // Add response metadata
      context->AddInitialMetadata("h1", "v1");
      context->AddTrailingMetadata("l1", "v1");

      // Create response
      response->set_status(200);
      TalkResult *talkResult = response->add_results();
      createResponse(id, talkResult);

      return Status::OK;
    }
  }

  /**
   * @brief Implements the server streaming RPC method
   */
  Status TalkOneAnswerMore(ServerContext *context, const TalkRequest *request,
                           ServerWriter<TalkResponse> *writer) override {
    logHeaders(context, "TalkOneAnswerMore");

    if (client) {
      // Proxy mode - forward request to backend
      LOG(INFO) << "Proxying server streaming request to backend";
      grpc::ClientContext c;
      propagateHeaders(context, c);

      TalkResponse talkResponse;
      const auto &response = client->TalkOneAnswerMore(&c, *request);

      while (response->Read(&talkResponse)) {
        writer->Write(talkResponse);
      }
    } else {
      // Direct mode - handle locally
      const auto &data = request->data();
      LOG(INFO) << "Server streaming call received - data: " << data
                << ", meta: " << request->meta();

      // Split the comma-separated data
      std::regex ws_re(",");
      std::vector<std::string> ids{
          std::sregex_token_iterator(data.begin(), data.end(), ws_re, -1),
          std::sregex_token_iterator()};

      // Send a response for each data item
      for (const auto &id : ids) {
        TalkResponse response;
        response.set_status(200);
        TalkResult *talkResult = response.add_results();
        createResponse(id, talkResult);
        writer->Write(response);
      }
    }

    return Status::OK;
  }

  /**
   * @brief Implements the client streaming RPC method
   */
  Status TalkMoreAnswerOne(ServerContext *context,
                           ServerReader<TalkRequest> *reader,
                           TalkResponse *response) override {
    logHeaders(context, "TalkMoreAnswerOne");

    if (client) {
      // Proxy mode - forward requests to backend
      LOG(INFO) << "Proxying client streaming request to backend";
      grpc::ClientContext c;
      propagateHeaders(context, c);

      auto writer = client->TalkMoreAnswerOne(&c, response);
      TalkRequest request;

      while (reader->Read(&request)) {
        if (!writer->Write(request)) {
          // Stream has been closed
          LOG(WARNING) << "Backend stream closed prematurely";
          break;
        }
      }

      writer->WritesDone();
      return writer->Finish();
    } else {
      // Direct mode - handle locally
      response->set_status(200);
      TalkRequest request;

      while (reader->Read(&request)) {
        const auto &id = request.data();
        LOG(INFO) << "Client streaming request received - data: " << id
                  << ", meta: " << request.meta();

        TalkResult *talkResult = response->add_results();
        createResponse(id, talkResult);
      }

      return Status::OK;
    }
  }

  /**
   * @brief Implements the bidirectional streaming RPC method
   */
  Status TalkBidirectional(
      ServerContext *context,
      ServerReaderWriter<TalkResponse, TalkRequest> *stream) override {
    logHeaders(context, "TalkBidirectional");

    if (client) {
      // Proxy mode - forward request to backend
      LOG(INFO) << "Proxying bidirectional streaming request to backend";
      grpc::ClientContext c;
      propagateHeaders(context, c);

      TalkResponse talkResponse;
      auto s = client->TalkBidirectional(&c);
      TalkRequest request;

      // Forward client requests to backend
      while (stream->Read(&request)) {
        s->Write(request);
      }

      // Forward backend responses to client
      while (s->Read(&talkResponse)) {
        stream->Write(talkResponse);
      }

      return s->Finish();
    } else {
      // Direct mode - handle locally
      TalkRequest request;

      while (stream->Read(&request)) {
        const auto &id = request.data();
        LOG(INFO) << "Bidirectional streaming request received - data: " << id
                  << ", meta: " << request.meta();

        TalkResponse response;
        response.set_status(200);
        TalkResult *talkResult = response.add_results();
        createResponse(id, talkResult);
        stream->Write(response);
      }

      return Status::OK;
    }
  }

  /**
   * @brief Creates a response object with the appropriate data
   *
   * @param id The request ID (typically a language index)
   * @param talkResult Pointer to TalkResult to populate
   */
  static void createResponse(const std::string &id, TalkResult *talkResult) {
    talkResult->set_id(Utils::now());
    talkResult->set_type(ResultType::OK);

    auto *pMap = talkResult->mutable_kv();
    int index = std::stoi(id);
    const auto &uuid = Utils::uuid();

    // Add response metadata
    (*pMap)["id"] = uuid;
    (*pMap)["idx"] = id;
    (*pMap)["meta"] = "C++";

    // Get greeting and response
    const auto &hello = Utils::hello(index);
    (*pMap)["data"] = hello + "," + Utils::thanks(hello);
  }

  /**
   * @brief Logs request headers for debugging
   *
   * @param context Server context containing headers
   * @param methodName Name of the RPC method for logging
   */
  static void logHeaders(const ServerContext *context,
                         const std::string &methodName) {
    const auto &metadata = context->client_metadata();
    for (const auto &[key, value] : metadata) {
      LOG(INFO) << methodName << " - header: " << key << ":" << value;
    }
  }

  /**
   * @brief Propagates tracing headers from server context to client context
   *
   * @param context Server context containing headers
   * @param clientContext Client context to propagate headers to
   */
  static void propagateHeaders(const ServerContext *context,
                               grpc::ClientContext &clientContext) {
    const auto &metadata = context->client_metadata();

    // Copy trace headers to outgoing request
    for (const auto &header : TRACING_HEADERS) {
      auto it = metadata.find(header);
      if (it != metadata.end()) {
        const std::string headerValue(it->second.begin(), it->second.end());
        clientContext.AddMetadata(header, headerValue);
        LOG(INFO) << "Propagating header: " << header << ":" << headerValue;
      }
    }
  }

  /**
   * @brief Sets the backend channel for proxy mode
   *
   * @param channel Shared pointer to gRPC channel
   */
  void setChannel(const std::shared_ptr<grpc::Channel> &channel) {
    if (channel) {
      client = LandingService::NewStub(channel);
      LOG(INFO) << "Backend client configured";
    }
  }

private:
  /** Backend client stub for proxy mode */
  std::unique_ptr<LandingService::Stub> client;
};

/**
 * @brief Creates and starts the gRPC server
 *
 * Configures the server with TLS if enabled, and registers
 * the LandingService implementation.
 */
void RunServer() {
  const auto &port = Utils::getServerPort();
  std::string server_address("0.0.0.0:" + port);

  // Log certificate paths
  LOG(INFO) << "Using certificate paths:";
  LOG(INFO) << "  Certificate: " << cert;
  LOG(INFO) << "  Key: " << certKey;
  LOG(INFO) << "  Chain: " << certChain;
  LOG(INFO) << "  Root: " << rootCert;

  // Enable health check and reflection services
  grpc::EnableDefaultHealthCheckService(true);
  grpc::reflection::InitProtoReflectionServerBuilderPlugin();

  ServerBuilder builder;
  const auto &secure = Utils::getSecure();

  // Configure server with TLS if enabled
  if (!secure.empty() && secure == "Y") {
    LOG(INFO) << "Starting secure gRPC server with TLS on port " << port
              << " [version: " << Utils::getVersion() << "]";

    try {
      // Check if certificate files exist
      if (!std::filesystem::exists(certKey) ||
          !std::filesystem::exists(certChain)) {
        throw std::runtime_error("Certificate files not found");
      }

      grpc::SslServerCredentialsOptions ssl_opts(
          GRPC_SSL_REQUEST_CLIENT_CERTIFICATE_BUT_DONT_VERIFY);

      ssl_opts.pem_root_certs = Connection::getFileContent(rootCert.c_str());
      grpc::SslServerCredentialsOptions::PemKeyCertPair pemKeyCertPair;
      pemKeyCertPair.private_key = Connection::getFileContent(certKey.c_str());
      pemKeyCertPair.cert_chain = Connection::getFileContent(certChain.c_str());
      ssl_opts.pem_key_cert_pairs.push_back(pemKeyCertPair);

      LOG(INFO) << "TLS configuration: root_certs=" << ssl_opts.pem_root_certs.size() 
                << " bytes, private_key=" << pemKeyCertPair.private_key.size()
                << " bytes, cert_chain=" << pemKeyCertPair.cert_chain.size() << " bytes";

      builder.AddListeningPort(server_address,
                               grpc::SslServerCredentials(ssl_opts));
    } catch (const std::exception &e) {
      LOG(ERROR) << "Failed to configure TLS: " << e.what()
                 << ". Falling back to insecure mode.";
      builder.AddListeningPort(server_address,
                               grpc::InsecureServerCredentials());
    }
  } else {
    LOG(INFO) << "Starting insecure gRPC server on port " << port
              << " [version: " << Utils::getVersion() << "]";
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
  }

  // Create and configure service implementation
  LandingServiceImpl landingService;
  const char *backend = std::getenv("GRPC_HELLO_BACKEND");
  std::string endpoint(backend ? backend : "");

  if (!endpoint.empty()) {
    LOG(INFO) << "Operating in proxy mode with backend at " << endpoint;
    landingService.setChannel(Connection::getChannel());
  } else {
    LOG(INFO) << "Operating in standalone mode (no backend)";
  }

  builder.RegisterService(&landingService);

  // Start the server
  std::unique_ptr<Server> server(builder.BuildAndStart());
  LOG(INFO) << "Server listening on " << server_address;

  // Wait for server to shutdown
  server->Wait();
}

/**
 * @brief Main entry point for the application
 */
int main(int argc, char **argv) {
  // Initialize logging
  Utils::initLog(argv);

  // Run the server
  try {
    RunServer();
  } catch (const std::exception &e) {
    LOG(ERROR) << "Server failed with error: " << e.what();
    google::ShutdownGoogleLogging();
    return 1;
  }

  LOG(WARNING) << "gRPC C++ server shutting down";
  google::ShutdownGoogleLogging();
  return 0;
}
