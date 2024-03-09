#include <catch2/catch_test_macros.hpp>
#include <catch2/catch_session.hpp>
#include <glog/logging.h>
#include "utils.h"


TEST_CASE("Hello List[1] is Bonjour", "[single-file]")
{
    const string &hello = hello::Utils::hello(1);
    LOG(INFO) << "hello:" << hello;
    REQUIRE(hello == "Bonjour");
    const string &thanks= hello::Utils::thanks(hello);
    LOG(INFO) << "thanks:" << thanks;
    REQUIRE(thanks == "Merci beaucoup");
}

int main(__attribute__((unused)) int argc, char **argv) {
    // your setup ...
    hello::Utils::initLog(argv);
    int result = Catch::Session().run(argc, argv);
    // your clean-up...

    return result;
}