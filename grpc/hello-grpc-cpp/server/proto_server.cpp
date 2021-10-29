#include <iostream>
#include <memory>
#include <string>

#include <grpcpp/ext/proto_server_reflection_plugin.h>
#include <grpcpp/grpcpp.h>
#include <grpcpp/health_check_service_interface.h>

#include "landing.grpc.pb.h"
#include <glog/logging.h>
#include <regex>
#include "connection.h"
#include "utils.h"

using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::Status;
using org::feuyeux::grpc::LandingService;
using org::feuyeux::grpc::TalkRequest;
using org::feuyeux::grpc::TalkResponse;
using org::feuyeux::grpc::TalkResult;
using org::feuyeux::grpc::ResultType;
using grpc::ServerWriter;
using grpc::ServerReader;
using grpc::ServerReaderWriter;
using std::string;
using google::protobuf::Map;
using hello::Connection;
using hello::Utils;

//https://myssl.com/create_test_cert.html
const char cert[] = "/var/hello_grpc/server_certs/cert.pem";
const char certKey[] = "/var/hello_grpc/server_certs/private.pkcs8.key";
const char certChain[] = "/var/hello_grpc/server_certs/full_chain.pem";
const char rootCert[] = "/var/hello_grpc/server_certs/myssl_root.cer";

class LandingServiceImpl final : public LandingService::Service {
public:
    std::vector<string> HELLO_LIST{"Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"};

    Status Talk(ServerContext *context, const TalkRequest *request, TalkResponse *response) override {
        // Get the client's initial metadata
        std::cout << "Client metadata: " << std::endl;
        const std::multimap<grpc::string_ref, grpc::string_ref> metadata = context->client_metadata();
        for (auto iter = metadata.begin(); iter != metadata.end(); ++iter) {
            std::cout << "Header key: " << iter->first << ", value: ";
            // Check for binary value
            size_t isbin = iter->first.find("-bin");
            if ((isbin != std::string::npos) && (isbin + 4 == iter->first.size())) {
                std::cout << std::hex;
                for (auto c: iter->second) {
                    std::cout << static_cast<unsigned int>(c);
                }
                std::cout << std::dec;
            } else {
                std::cout << iter->second;
            }
            std::cout << std::endl;
        }
        context->AddInitialMetadata("custom-server-metadata", "initial metadata value");
        context->AddTrailingMetadata("custom-trailing-metadata", "trailing metadata value");

        const string &id = request->data();
        LOG(INFO) << "TALK REQUEST: data=" << id << ", meta=" << request->meta();
        response->set_status(200);
        TalkResult *talkResult;
        talkResult = response->add_results();
        buildResult(id, talkResult);
        return Status::OK;
    }

    Status
    TalkOneAnswerMore(ServerContext *context, const TalkRequest *request,
                      ServerWriter<TalkResponse> *writer) override {
        const string &data = request->data();
        LOG(INFO) << "TalkOneAnswerMore REQUEST: data=" << data << ", meta=" << request->meta();
        std::regex ws_re(",");
        std::vector<std::string> ids(std::sregex_token_iterator(data.begin(), data.end(), ws_re, -1),
                                     std::sregex_token_iterator());
        for (const string &id: ids) {
            TalkResponse response;
            response.set_status(200);
            TalkResult *talkResult;
            talkResult = response.add_results();
            buildResult(id, talkResult);
            writer->Write(response);
        }
        return Status::OK;
    }

    Status
    TalkMoreAnswerOne(ServerContext *context, ServerReader<TalkRequest> *reader, TalkResponse *response) override {
        TalkRequest request;
        while (reader->Read(&request)) {
            const string &id = request.data();
            LOG(INFO) << "TalkMoreAnswerOne REQUEST: data=" << id << ", meta=" << request.meta();
            response->set_status(200);
            TalkResult *talkResult;
            talkResult = response->add_results();
            buildResult(id, talkResult);
        }
        return Status::OK;
    }

    Status TalkBidirectional(ServerContext *context, ServerReaderWriter<TalkResponse, TalkRequest> *stream) override {
        TalkRequest request;
        while (stream->Read(&request)) {
            const string &id = request.data();
            LOG(INFO) << "TalkBidirectional REQUEST: data=" << id << ", meta=" << request.meta();
            TalkResponse response;
            response.set_status(200);
            TalkResult *talkResult;
            talkResult = response.add_results();
            buildResult(id, talkResult);
            stream->Write(response);
        }
        return Status::OK;
    }

    void buildResult(const string id, TalkResult *talkResult) {
        talkResult->set_id(Utils::now());
        talkResult->set_type(ResultType::OK);
        google::protobuf::Map<string, string> *pMap = talkResult->mutable_kv();
        int index = stoi(id);
        (*pMap)["id"] = "UUID-TODO";
        (*pMap)["idx"] = id;
        (*pMap)["meta"] = "c++";
        (*pMap)["data"] = HELLO_LIST[index];
    }
};

void RunServer() {
    const string &port = Utils::getGrcServerPort();
    std::string server_address("0.0.0.0:" + port);

    grpc::EnableDefaultHealthCheckService(true);
    grpc::reflection::InitProtoReflectionServerBuilderPlugin();
    ServerBuilder builder;
    const string &secure = Utils::getSecure();
    if (!secure.empty() && secure == "Y") {
        LOG(INFO) << "Start GRPC TLS Server[" << port << "]";
        grpc::SslServerCredentialsOptions ssl_opts(GRPC_SSL_REQUEST_CLIENT_CERTIFICATE_BUT_DONT_VERIFY);
        ssl_opts.pem_root_certs = Connection::getFileContent(rootCert);
        grpc::SslServerCredentialsOptions::PemKeyCertPair pemKeyCertPair;
        pemKeyCertPair.private_key = Connection::getFileContent(certKey).c_str();
        pemKeyCertPair.cert_chain = Connection::getFileContent(certChain).c_str();
        ssl_opts.pem_key_cert_pairs.push_back({pemKeyCertPair});
        builder.AddListeningPort(server_address, grpc::SslServerCredentials(ssl_opts));
    } else {
        LOG(INFO) << "Start GRPC Server[" << port << "]";
        builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
    }
    LandingServiceImpl landingService;
    builder.RegisterService(&landingService);

    std::unique_ptr<Server> server(builder.BuildAndStart());
    LOG(INFO) << "Server listening on " << server_address;
    server->Wait();
}

int main(int argc, char **argv) {
    Utils::initLog(argv);
    RunServer();
    LOG(WARNING) << "Hello gRPC C++ Server is stopping";
    google::ShutdownGoogleLogging();
    return 0;
}

//TODO UUID https://github.com/r-lyeh-archived/sole
