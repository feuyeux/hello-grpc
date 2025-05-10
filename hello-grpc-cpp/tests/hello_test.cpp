#include "grpcpp/grpcpp.h"
#include "utils.h"
#include <catch2/catch_session.hpp>
#include <catch2/catch_test_macros.hpp>
#include <glog/logging.h>

TEST_CASE("Hello List[1] is Bonjour", "[single-file]") {
  const string &hello = hello::Utils::hello(1);
  LOG(INFO) << "hello:" << hello;
  REQUIRE(hello == "Bonjour");
  const string &thanks = hello::Utils::thanks(hello);
  LOG(INFO) << "thanks:" << thanks;
  REQUIRE(thanks == "Merci beaucoup");
}

TEST_CASE("gRPC version is retrieved correctly", "[grpc-version]") {
  const string &version = hello::Utils::getVersion();
  LOG(INFO) << "gRPC version: " << version;
  std::cout << "gRPC version from Utils::getVersion(): " << version
            << std::endl;

  // Test that the version string starts with the correct prefix
  REQUIRE(version.substr(0, 13) == "grpc.version=");

  // Test that we're getting the same result as the direct call
  const string directVersion = "grpc.version=" + grpc::Version();
  std::cout << "Direct gRPC version: " << directVersion << std::endl;
  REQUIRE(version == directVersion);

  // Test that the version is not empty (beyond the prefix)
  REQUIRE(version.length() > 13);
}

int main(__attribute__((unused)) int argc, char **argv) {
  // your setup ...
  hello::Utils::initLog(argv);
  int result = Catch::Session().run(argc, argv);
  // your clean-up...

  return result;
}