#include <chrono>
#include <stdlib.h>
#include <string>
#include <glog/logging.h>
#include "utils.h"

using std::getenv;

namespace hello {
    int Utils::random(int n) {
        int a = 0;
        int b = n;
        return (rand() % (b - a + 1)) + a;
    }

    long Utils::now() {
        const auto now = chrono::system_clock::now();
        auto value = now.time_since_epoch().count();
        return value;
    }

    string Utils::getGrcServerHost() {
        const char *server_address = getenv("GRPC_SERVER");
        string endpoint(server_address ? server_address : "localhost");
        return endpoint;
    }

    string Utils::getGrcServerPort() {
        const char *port = getenv("GRPC_SERVER_PORT");
        string endpoint(port ? port : "9996");
        return endpoint;
    }

    string Utils::getBackend() {
        const char *server_address = getenv("GRPC_HELLO_BACKEND");
        string endpoint(server_address ? server_address : "");
        if (endpoint.empty()) {
            return getGrcServerHost();
        }
        return endpoint;
    }

    string Utils::getSecure() {
        const char *isTls = getenv("GRPC_HELLO_SECURE");
        string secure(isTls ? isTls : "");
        return secure;
    }

    void Utils::initLog(char *const *argv) {
        /*
         * 日志文件名 <program name>.<host name>.<user name>.log.<Severity level>.<date>-<time>.<pid>
         * 日志格式 [IWEF]yyyymmdd hh:mm:ss.uuuuuu threadid file:line] msg
         */
        google::InitGoogleLogging(argv[0]);
        /*
         * sudo mkdir /opt/hello-grpc
         * sudo chown -R $(whoami) /opt/hello-grpc
         */
        google::SetLogDestination(google::INFO, "/opt/hello-grpc/");
        FLAGS_colorlogtostderr = true;
        FLAGS_alsologtostderr = true;
    }
}