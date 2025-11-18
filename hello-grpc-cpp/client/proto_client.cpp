/**
 * @file proto_client.cpp
 * @brief gRPC client implementation demonstrating all four RPC patterns
 *
 * This client follows the standardized structure:
 * 1. Configuration constants
 * 2. Logger initialization
 * 3. Connection setup
 * 4. RPC method implementations (unary, server streaming, client streaming, bidirectional)
 * 5. Helper functions
 * 6. Main execution function
 * 7. Cleanup and shutdown
 */

#include <chrono>
#include <csignal>
#include <iostream>
#include <memory>
#include <string>
#include <thread>

#include "glog/logging.h"
#include "grpcpp/grpcpp.h"

#include "common/connection.h"
#include "common/error_mapper.h"
#include "common/utils.h"
#include "protos/landing.grpc.pb.h"

using google::protobuf::Map;
using grpc::Channel;
using grpc::ClientContext;
using grpc::ClientReader;
using grpc::ClientReaderWriter;
using grpc::ClientWriter;
using grpc::Status;
using hello::Connection;
using hello::LandingService;
using hello::ResultType;
using hello::TalkRequest;
using hello::TalkResponse;
using hello::TalkResult;
using hello::Utils;

// Configuration constants
constexpr int RETRY_ATTEMPTS = 3;
constexpr int RETRY_DELAY_MS = 2000;
constexpr int ITERATION_COUNT = 3;
constexpr int REQUEST_DELAY_MS = 200;
constexpr int SEND_DELAY_MS = 2;
constexpr int REQUEST_TIMEOUT_SECONDS = 5;
constexpr int DEFAULT_BATCH_SIZE = 5;

// Global flag for graceful shutdown
volatile sig_atomic_t shutdown_requested = 0;

/**
 * @brief Signal handler for graceful shutdown
 */
void signal_handler(int signal) {
  LOG(INFO) << "Received shutdown signal, cancelling operations";
  shutdown_requested = 1;
}

/**
 * @brief gRPC client class implementing all four RPC patterns
 */
class ProtoClient {
public:
  /**
   * @brief Constructs a client with the given channel
   * @param channel Shared pointer to gRPC channel
   */
  explicit ProtoClient(std::shared_ptr<Channel> channel)
      : stub_(LandingService::NewStub(std::move(channel))) {}

  /**
   * @brief Executes a unary RPC call (single request, single response)
   * @param request The request to send
   * @return The response from the server
   */
  TalkResponse execute_unary_call(const TalkRequest &request) {
    std::string request_id = "unary-" + std::to_string(Utils::now());
    LOG(INFO) << "Sending unary request: data=" << request.data()
              << ", meta=" << request.meta();

    ClientContext context;
    add_metadata(context);
    set_deadline(context, REQUEST_TIMEOUT_SECONDS);

    TalkResponse response;
    auto start_time = std::chrono::steady_clock::now();

    Status status = stub_->Talk(&context, request, &response);
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
                        std::chrono::steady_clock::now() - start_time)
                        .count();

    if (status.ok()) {
      LOG(INFO) << "Unary call successful in " << duration << "ms";
      return response;
    } else {
      log_error(status, request_id, "Talk");
      throw std::runtime_error("Unary call failed: " + status.error_message());
    }
  }

  /**
   * @brief Executes a server streaming RPC call (single request, multiple
   * responses)
   * @param request The request to send
   */
  void execute_server_streaming_call(const TalkRequest &request) {
    std::string request_id = "server-stream-" + std::to_string(Utils::now());
    LOG(INFO) << "Starting server streaming with request: data="
              << request.data() << ", meta=" << request.meta();

    ClientContext context;
    add_metadata(context);
    set_deadline(context, REQUEST_TIMEOUT_SECONDS);

    auto start_time = std::chrono::steady_clock::now();
    int response_count = 0;

    std::unique_ptr<ClientReader<TalkResponse>> reader(
        stub_->TalkOneAnswerMore(&context, request));

    TalkResponse response;
    while (reader->Read(&response)) {
      if (shutdown_requested) {
        LOG(INFO) << "Server streaming cancelled";
        break;
      }
      response_count++;
      LOG(INFO) << "Received server streaming response #" << response_count
                << ":";
      log_response(response);
    }

    Status status = reader->Finish();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
                        std::chrono::steady_clock::now() - start_time)
                        .count();

    if (status.ok()) {
      LOG(INFO) << "Server streaming completed: received " << response_count
                << " responses in " << duration << "ms";
    } else {
      log_error(status, request_id, "TalkOneAnswerMore");
      throw std::runtime_error("Server streaming failed: " +
                               status.error_message());
    }
  }

  /**
   * @brief Executes a client streaming RPC call (multiple requests, single
   * response)
   * @param requests List of requests to send
   * @return The response from the server
   */
  TalkResponse
  execute_client_streaming_call(const std::list<TalkRequest> &requests) {
    std::string request_id = "client-stream-" + std::to_string(Utils::now());
    LOG(INFO) << "Starting client streaming with " << requests.size()
              << " requests";

    ClientContext context;
    add_metadata(context);
    set_deadline(context, REQUEST_TIMEOUT_SECONDS);

    TalkResponse response;
    auto start_time = std::chrono::steady_clock::now();

    std::unique_ptr<ClientWriter<TalkRequest>> writer(
        stub_->TalkMoreAnswerOne(&context, &response));

    int request_count = 0;
    for (const auto &request : requests) {
      if (shutdown_requested) {
        LOG(INFO) << "Client streaming cancelled";
        break;
      }

      request_count++;
      LOG(INFO) << "Sending client streaming request #" << request_count
                << ": data=" << request.data() << ", meta=" << request.meta();

      if (!writer->Write(request)) {
        LOG(WARNING) << "Stream closed prematurely";
        break;
      }

      std::this_thread::sleep_for(std::chrono::milliseconds(SEND_DELAY_MS));
    }

    writer->WritesDone();
    Status status = writer->Finish();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
                        std::chrono::steady_clock::now() - start_time)
                        .count();

    if (status.ok()) {
      LOG(INFO) << "Client streaming completed: sent " << request_count
                << " requests in " << duration << "ms";
      return response;
    } else {
      log_error(status, request_id, "TalkMoreAnswerOne");
      throw std::runtime_error("Client streaming failed: " +
                               status.error_message());
    }
  }

  /**
   * @brief Executes a bidirectional streaming RPC call (multiple requests,
   * multiple responses)
   * @param requests List of requests to send
   */
  void execute_bidirectional_streaming_call(
      const std::list<TalkRequest> &requests) {
    std::string request_id =
        "bidirectional-" + std::to_string(Utils::now());
    LOG(INFO) << "Starting bidirectional streaming with " << requests.size()
              << " requests";

    ClientContext context;
    add_metadata(context);
    set_deadline(context, REQUEST_TIMEOUT_SECONDS);

    auto start_time = std::chrono::steady_clock::now();
    int response_count = 0;

    std::shared_ptr<ClientReaderWriter<TalkRequest, TalkResponse>> stream(
        stub_->TalkBidirectional(&context));

    // Thread to handle sending requests
    std::thread writer_thread([&stream, &requests]() {
      int request_count = 0;
      for (const auto &request : requests) {
        if (shutdown_requested) {
          break;
        }

        request_count++;
        LOG(INFO) << "Sending bidirectional streaming request #"
                  << request_count << ": data=" << request.data()
                  << ", meta=" << request.meta();

        if (!stream->Write(request)) {
          LOG(WARNING) << "Stream closed prematurely";
          break;
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(SEND_DELAY_MS));
      }

      LOG(INFO) << "Closing send side of bidirectional stream";
      stream->WritesDone();
    });

    // Main thread handles receiving responses
    TalkResponse response;
    while (stream->Read(&response)) {
      if (shutdown_requested) {
        LOG(INFO) << "Bidirectional streaming cancelled";
        break;
      }

      response_count++;
      LOG(INFO) << "Received bidirectional streaming response #"
                << response_count << ":";
      log_response(response);
    }

    writer_thread.join();
    Status status = stream->Finish();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
                        std::chrono::steady_clock::now() - start_time)
                        .count();

    if (status.ok()) {
      LOG(INFO) << "Bidirectional streaming completed in " << duration << "ms";
    } else {
      log_error(status, request_id, "TalkBidirectional");
      throw std::runtime_error("Bidirectional streaming failed: " +
                               status.error_message());
    }
  }

  /**
   * @brief Logs the response in a standardized format
   * @param response The response to log
   */
  static void log_response(const TalkResponse &response) {
    int results_count = response.results_size();
    LOG(INFO) << "Response status: " << response.status()
              << ", results: " << results_count;

    for (int i = 0; i < results_count; i++) {
      const auto &result = response.results(i);
      const auto &kv = result.kv();

      std::string meta = kv.count("meta") ? kv.at("meta") : "";
      std::string id = kv.count("id") ? kv.at("id") : "";
      std::string idx = kv.count("idx") ? kv.at("idx") : "";
      std::string data = kv.count("data") ? kv.at("data") : "";

      LOG(INFO) << "  Result #" << (i + 1) << ": id=" << result.id()
                << ", type=" << ResultType_Name(result.type())
                << ", meta=" << meta << ", id=" << id << ", idx=" << idx
                << ", data=" << data;
    }
  }

private:
  /**
   * @brief Adds standard metadata to the context
   * @param context The client context to add metadata to
   */
  static void add_metadata(ClientContext &context) {
    context.AddMetadata("k1", "v1");
    context.AddMetadata("k2", "v2");
  }

  /**
   * @brief Sets a deadline for the RPC call
   * @param context The client context to set deadline on
   * @param timeout_seconds Timeout in seconds
   */
  static void set_deadline(ClientContext &context, int timeout_seconds) {
    context.set_deadline(std::chrono::system_clock::now() +
                         std::chrono::seconds(timeout_seconds));
  }

  /**
   * @brief Logs gRPC errors in a standardized format
   * @param status The gRPC status
   * @param request_id The request ID for context
   * @param operation The operation name
   */
  static void log_error(const Status &status, const std::string &request_id,
                        const std::string &operation) {
    LOG(ERROR) << "[request_id=" << request_id << "] " << operation
               << " failed: code=" << ErrorMapper::StatusCodeToString(status.code())
               << ", message=" << status.error_message();
  }

  std::unique_ptr<LandingService::Stub> stub_;
};

/**
 * @brief Runs all four gRPC patterns multiple times
 * @param client The client instance to use
 * @param delay_ms Delay between iterations in milliseconds
 * @param iterations Number of times to run all patterns
 * @return true if all calls completed successfully, false otherwise
 */
bool run_grpc_calls(ProtoClient &client, int delay_ms, int iterations) {
  for (int iteration = 1; iteration <= iterations; iteration++) {
    if (shutdown_requested) {
      LOG(INFO) << "Client execution cancelled";
      return false;
    }

    LOG(INFO) << "====== Starting iteration " << iteration << "/" << iterations
              << " ======";

    try {
      // 1. Unary RPC
      LOG(INFO) << "----- Executing unary RPC -----";
      TalkRequest unary_request;
      unary_request.set_data("0");
      unary_request.set_meta("C++");
      TalkResponse response = client.execute_unary_call(unary_request);
      ProtoClient::log_response(response);

      // 2. Server streaming RPC
      LOG(INFO) << "----- Executing server streaming RPC -----";
      TalkRequest server_stream_request;
      server_stream_request.set_data("0,1,2");
      server_stream_request.set_meta("C++");
      client.execute_server_streaming_call(server_stream_request);

      // 3. Client streaming RPC
      LOG(INFO) << "----- Executing client streaming RPC -----";
      const auto &client_stream_requests = Utils::buildLinkRequests();
      TalkResponse client_stream_response =
          client.execute_client_streaming_call(client_stream_requests);
      ProtoClient::log_response(client_stream_response);

      // 4. Bidirectional streaming RPC
      LOG(INFO) << "----- Executing bidirectional streaming RPC -----";
      const auto &bidirectional_requests = Utils::buildLinkRequests();
      client.execute_bidirectional_streaming_call(bidirectional_requests);

      // Wait before next iteration, unless it's the last one
      if (iteration < iterations) {
        LOG(INFO) << "Waiting " << delay_ms << "ms before next iteration...";
        std::this_thread::sleep_for(std::chrono::milliseconds(delay_ms));
      }

    } catch (const std::exception &e) {
      if (shutdown_requested) {
        LOG(INFO) << "Client execution cancelled";
        return false;
      }
      LOG(ERROR) << "Error in iteration " << iteration << ": " << e.what();
      return false;
    }
  }

  LOG(INFO) << "All gRPC calls completed successfully";
  return true;
}

/**
 * @brief Main entry point for the client application
 */
int main(int argc, char **argv) {
  // Initialize logging
  Utils::initLog(argv);

  // Setup signal handling for graceful shutdown
  std::signal(SIGINT, signal_handler);
  std::signal(SIGTERM, signal_handler);

  LOG(INFO) << "Starting gRPC client [version: " << Utils::getVersion() << "]";

  bool success = false;

  // Attempt to establish connection and run all patterns
  for (int attempt = 1; attempt <= RETRY_ATTEMPTS; attempt++) {
    if (shutdown_requested) {
      LOG(INFO) << "Client shutting down, aborting retries";
      break;
    }

    LOG(INFO) << "Connection attempt " << attempt << "/" << RETRY_ATTEMPTS;

    try {
      // Create client and run all gRPC patterns
      ProtoClient client(Connection::getChannel());
      success = run_grpc_calls(client, REQUEST_DELAY_MS, ITERATION_COUNT);

      if (success || shutdown_requested) {
        break; // Success or deliberate cancellation, no retry needed
      }

    } catch (const std::exception &e) {
      LOG(ERROR) << "Connection attempt " << attempt << " failed: " << e.what();
      if (attempt < RETRY_ATTEMPTS) {
        LOG(INFO) << "Retrying in " << RETRY_DELAY_MS << "ms...";
        std::this_thread::sleep_for(std::chrono::milliseconds(RETRY_DELAY_MS));
      } else {
        LOG(ERROR) << "Maximum connection attempts reached, exiting";
      }
    }
  }

  if (!success && !shutdown_requested) {
    LOG(ERROR) << "Failed to execute all gRPC calls successfully";
    google::ShutdownGoogleLogging();
    return 1;
  }

  if (shutdown_requested) {
    LOG(INFO) << "Client execution was cancelled";
  } else {
    LOG(INFO) << "Client execution completed successfully";
  }

  google::ShutdownGoogleLogging();
  return 0;
}