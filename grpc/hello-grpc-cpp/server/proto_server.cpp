#include <iostream>
#include <memory>
#include <string>

#include <grpcpp/ext/proto_server_reflection_plugin.h>
#include <grpcpp/grpcpp.h>
#include <grpcpp/health_check_service_interface.h>

#include "helloworld.grpc.pb.h"
#include "landing.grpc.pb.h"
#include "../client/utils.h"
#include <glog/logging.h>
#include <regex>

using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::Status;
using helloworld::Greeter;
using helloworld::HelloReply;
using helloworld::HelloRequest;
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
using hello::Utils;

class LandingServiceImpl final : public LandingService::Service {
public:
    std::vector<string> HELLO_LIST{"Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"};

    Status Talk(ServerContext *context, const TalkRequest *request, TalkResponse *response) override {
        const string &id = request->data();
        LOG(INFO) << "TALK REQUEST: data=" << id << ", meta=" << request->meta();
        response->set_status(200);
        TalkResult *talkResult;
        talkResult = response->add_results();
        buildResult(id, talkResult);
        return Status::OK;
    }

    Status
    TalkOneAnswerMore(ServerContext *context, const TalkRequest *request, ServerWriter<TalkResponse> *writer) override {
        const string &data = request->data();
        LOG(INFO) << "TalkOneAnswerMore REQUEST: data=" << data << ", meta=" << request->meta();
        std::regex ws_re(",");
        std::vector<std::string> ids(std::sregex_token_iterator(
                                             data.begin(), data.end(), ws_re, -1
                                     ),
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
        talkResult->set_id(Utils::Now());
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
    LOG(INFO) << "Hello gRPC C++ Server is starting...";
    std::string server_address("0.0.0.0:9996");

    grpc::EnableDefaultHealthCheckService(true);
    grpc::reflection::InitProtoReflectionServerBuilderPlugin();
    ServerBuilder builder;
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());

    LandingServiceImpl landingService;
    builder.RegisterService(&landingService);

    std::unique_ptr<Server> server(builder.BuildAndStart());
    LOG(INFO) << "Server listening on " << server_address;
    server->Wait();
}

int main(int argc, char **argv) {
    google::InitGoogleLogging(argv[0]);
    google::SetLogDestination(google::INFO, "/Users/han/hello_grpc/");
    FLAGS_colorlogtostderr = true;
    FLAGS_alsologtostderr = 1;
    RunServer();
    LOG(WARNING) << "Hello gRPC C++ Server is stopping";
    google::ShutdownGoogleLogging();
    return 0;
}
