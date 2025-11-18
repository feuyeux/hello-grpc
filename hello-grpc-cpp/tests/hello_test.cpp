/**
 * @file hello_test.cpp
 * @brief Unit tests for utility functions
 */

#include <iostream>
#include <string>

#include <catch2/catch_session.hpp>
#include <catch2/catch_test_macros.hpp>
#include <glog/logging.h>

#include "grpcpp/grpcpp.h"
#include "utils.h"

TEST_CASE("Hello List[1] is Bonjour", "[single-file]") {
  const std::string &hello = hello::Utils::hello(1);
  LOG(INFO) << "hello:" << hello;
  REQUIRE(hello == "Bonjour");
  const std::string &thanks = hello::Utils::thanks(hello);
  LOG(INFO) << "thanks:" << thanks;
  REQUIRE(thanks == "Merci beaucoup");
}

TEST_CASE("gRPC version is retrieved correctly", "[grpc-version]") {
  const std::string &version = hello::Utils::getVersion();
  LOG(INFO) << "gRPC version: " << version;
  std::cout << "gRPC version from Utils::getVersion(): " << version
            << std::endl;

  // Test that the version string starts with the correct prefix
  REQUIRE(version.substr(0, 13) == "grpc.version=");

  // Test that we're getting the same result as the direct call
  const std::string direct_version = "grpc.version=" + grpc::Version();
  std::cout << "Direct gRPC version: " << direct_version << std::endl;
  REQUIRE(version == direct_version);

  // Test that the version is not empty (beyond the prefix)
  REQUIRE(version.length() > 13);
}

int main(__attribute__((unused)) int argc, char **argv) {
  // Initialize logging
  hello::Utils::initLog(argv);

  // Run tests
  int result = Catch::Session().run(argc, argv);

  return result;
}