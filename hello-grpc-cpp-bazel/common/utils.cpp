#include <chrono>
#include <string>
#include <glog/logging.h>
#include "utils.h"
#include <map>
#include <list>
#include <random>
#include "absl/strings/str_cat.h"
#include "absl/random/distributions.h"
#include "absl/random/random.h"
#include <iostream>
#include <random>
#include <string>

using std::getenv;

namespace hello
{
    static vector<string> HELLO_LIST{"Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"};
    static map<string, string> ANS_MAP = {
        {"你好", "非常感谢"},
        {"Hello", "Thank you very much"},
        {"Bonjour", "Merci beaucoup"},
        {"Hola", "Muchas Gracias"},
        {"こんにちは", "どうも ありがとう ございます"},
        {"Ciao", "Mille Grazie"},
        {"안녕하세요", "대단히 감사합니다"}};

    string Utils::hello(int index)
    {
        return HELLO_LIST[index];
    }

    string Utils::uuid()
    {
        /*absl::BitGen bit_gen;
        absl::uniform_int_distribution<uint32_t> distribution;
        uint32_t random_uuid = distribution(bit_gen);
        std::string uuid = absl::StrCat(absl::FormatTime("%Y-%m-%d-%H-%M-%S-", absl::Now(), absl::LocalTimeZone()), random_uuid);*/
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

    string Utils::thanks(string key)
    {
        return ANS_MAP[key];
    }

    list<TalkRequest> Utils::buildLinkRequests()
    {
        list<TalkRequest> requests = {};
        TalkRequest talkRequest;
        for (int i = 0; i < 3; ++i)
        {
            string data = grpc::to_string(random(5));
            // std::to_string
            talkRequest.set_data(data);
            talkRequest.set_meta("C++");
            requests.push_front(talkRequest);
        }
        return requests;
    }

    int Utils::random(int n)
    {
        int a = 0;
        int b = n;
        return (rand() % (b - a + 1)) + a;
    }

    long Utils::now()
    {
        const auto now = chrono::system_clock::now();
        auto value = now.time_since_epoch().count();
        return value;
    }

    string Utils::getServerHost()
    {
        const char *server_address = getenv("GRPC_SERVER");
        string endpoint(server_address ? server_address : "localhost");
        return endpoint;
    }

    string Utils::getServerPort()
    {
        const char *serverPort = getenv("GRPC_SERVER_PORT");
        string port(serverPort ? serverPort : "9996");
        return port;
    }

    string Utils::getBackendPort()
    {
        const char *port = getenv("GRPC_HELLO_BACKEND_PORT");
        string backendPort(port ? port : "");
        if (backendPort.empty())
        {
            return getServerPort();
        }
        return backendPort;
    }

    string Utils::getBackend()
    {
        const char *server_address = getenv("GRPC_HELLO_BACKEND");
        string endpoint(server_address ? server_address : "");
        if (endpoint.empty())
        {
            return getServerHost();
        }
        return endpoint;
    }

    string Utils::getSecure()
    {
        const char *isTls = getenv("GRPC_HELLO_SECURE");
        string secure(isTls ? isTls : "");
        return secure;
    }

    void Utils::initLog(char *const *argv)
    {
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