/**
 * @file utils.cpp
 * @brief Implementation of utility functions for gRPC client and server
 */

#include "utils.h"

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <list>
#include <map>
#include <random>
#include <string>

#include "glog/logging.h"
#include "grpcpp/grpcpp.h"

namespace hello {

// Greeting messages in different languages
static std::vector<std::string> HELLO_LIST{"Hello", "Bonjour", "Hola",
                                           "こんにちは", "Ciao", "안녕하세요"};

// Thank you responses for each greeting
static std::map<std::string, std::string> ANS_MAP = {
    {"你好", "非常感谢"},
    {"Hello", "Thank you very much"},
    {"Bonjour", "Merci beaucoup"},
    {"Hola", "Muchas Gracias"},
    {"こんにちは", "どうも ありがとう ございます"},
    {"Ciao", "Mille Grazie"},
    {"안녕하세요", "대단히 감사합니다"}};

std::string Utils::hello(int index) {
  if (index >= 0 && index < static_cast<int>(HELLO_LIST.size())) {
    return HELLO_LIST[index];
  }
  return HELLO_LIST[0]; // Default to first greeting
}

std::string Utils::uuid() {
  std::random_device rd;
  std::mt19937 gen(rd());
  unsigned char bytes[16];
  std::generate(std::begin(bytes), std::end(bytes), std::ref(gen));

  std::string uuid_str;
  uuid_str += std::to_string((bytes[6] & 0x0F) << 4 | (bytes[7] & 0x0F));
  uuid_str += "-";
  uuid_str += std::to_string((bytes[8] & 0x3F) << 4 | (bytes[9] & 0x0F));
  uuid_str += "-";
  uuid_str += std::to_string((bytes[10] & 0x3F) << 4 | (bytes[11] & 0x0F));
  uuid_str += "-";
  uuid_str += std::to_string((bytes[12] & 0x3F) << 4 | (bytes[13] & 0x0F));
  uuid_str += "-";
  uuid_str += std::to_string(bytes[14] >> 4);
  uuid_str += std::to_string(bytes[14] & 0x0F);

  return uuid_str;
}

std::string Utils::thanks(std::string key) {
  auto it = ANS_MAP.find(key);
  if (it != ANS_MAP.end()) {
    return it->second;
  }
  return "Thank you"; // Default response
}

std::list<TalkRequest> Utils::buildLinkRequests() {
  std::list<TalkRequest> requests;

  for (int i = 0; i < 3; ++i) {
    TalkRequest talk_request;
    std::string data = std::to_string(random(5));
    talk_request.set_data(data);
    talk_request.set_meta("C++");
    requests.push_back(talk_request);
  }

  return requests;
}

int Utils::random(int n) {
  if (n <= 0) {
    return 0;
  }
  return rand() % (n + 1);
}

long Utils::now() {
  const auto now = std::chrono::system_clock::now();
  auto value = now.time_since_epoch().count();
  return value;
}

std::string Utils::getServerHost() {
  const char *server_address = std::getenv("GRPC_SERVER");
  return server_address ? server_address : "localhost";
}

std::string Utils::getServerPort() {
  const char *server_port = std::getenv("GRPC_SERVER_PORT");
  return server_port ? server_port : "9996";
}

std::string Utils::getBackendPort() {
  const char *port = std::getenv("GRPC_HELLO_BACKEND_PORT");
  std::string backend_port(port ? port : "");

  if (backend_port.empty()) {
    return getServerPort();
  }

  return backend_port;
}

std::string Utils::getBackend() {
  const char *server_address = std::getenv("GRPC_HELLO_BACKEND");
  std::string endpoint(server_address ? server_address : "");

  if (endpoint.empty()) {
    return getServerHost();
  }

  return endpoint;
}

std::string Utils::getSecure() {
  const char *is_tls = std::getenv("GRPC_HELLO_SECURE");
  return is_tls ? is_tls : "";
}

std::string Utils::getVersion() {
  return "grpc.version=" + grpc::Version();
}

void Utils::initLog(char *const *argv) {
  // Ensure log directory exists
#ifdef _WIN32
  system("if not exist log mkdir log");
  FLAGS_log_dir = "log\\";
#else
  system("mkdir -p log");
  FLAGS_log_dir = "log/";
#endif

  // Initialize Google Logging
  // Log file format: <program name>.<host name>.<user name>.log.<Severity
  // level>.<date>-<time>.<pid> Log format: [IWEF]yyyymmdd hh:mm:ss.uuuuuu
  // threadid file:line] msg
  google::InitGoogleLogging(argv[0]);

  // Enable console output with colors
  FLAGS_colorlogtostderr = true;
  FLAGS_alsologtostderr = true;

  // Set log file destination
  google::SetLogDestination(google::INFO, "log/hello-grpc.");

  // Set minimum log level
  FLAGS_minloglevel = google::INFO;

  // Disable default log prefix for cleaner output
  FLAGS_log_prefix = false;

  // Install failure signal handler for crash reporting
  google::InstallFailureSignalHandler();
}

} // namespace hello
