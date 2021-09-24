#include <iostream>
#include <memory>
#include <string>

#include <grpcpp/grpcpp.h>
#include "helloworld.grpc.pb.h"
#include "landing.grpc.pb.h"
#include "utils.h"
#include <glog/logging.h>
#include <thread>

using grpc::Channel;
using grpc::ClientContext;
using grpc::Status;
using helloworld::Greeter;
using helloworld::HelloReply;
using helloworld::HelloRequest;
using org::feuyeux::grpc::TalkRequest;
using org::feuyeux::grpc::TalkResponse;
using org::feuyeux::grpc::LandingService;
using org::feuyeux::grpc::TalkResult;
using org::feuyeux::grpc::ResultType;
using grpc::ClientReader;
using grpc::ClientWriter;
using grpc::ClientReaderWriter;
using google::protobuf::RepeatedPtrField;
using google::protobuf::Map;
using std::string;
using hello::Utils;

class LandingClient {
public:
    LandingClient(std::shared_ptr<Channel> channel) : client(LandingService::NewStub(channel)) {}

    void Talk() {
        ClientContext context;
        TalkResponse talkResponse;
        TalkRequest talkRequest;
        talkRequest.set_data("1");
        talkRequest.set_meta("c++");
        Status status = client->Talk(&context, talkRequest, &talkResponse);
        if (status.ok()) {
            printResponse(talkResponse);
        } else {
            LOG(INFO) << "Error:" << status.error_code() << ": " << status.error_message();
        }
    }

    void TalkOneAnswerMore() {
        ClientContext context;
        TalkResponse talkResponse;
        TalkRequest talkRequest;
        talkRequest.set_data("1,2,3");
        talkRequest.set_meta("c++");
        const std::unique_ptr<::grpc::ClientReader<TalkResponse>> &response(
                client->TalkOneAnswerMore(&context, talkRequest));
        while (response->Read(&talkResponse)) {
            printResponse(talkResponse);
        }
    }

    void TalkMoreAnswerOne() {
        ClientContext context;
        TalkResponse talkResponse;
        std::unique_ptr<ClientWriter<TalkRequest> > writer(
                client->TalkMoreAnswerOne(&context, &talkResponse));
        TalkRequest talkRequest;
        for (int i = 0; i < 3; ++i) {
            string data = grpc::to_string(hello::Utils::Random(5));
            //std::to_string
            talkRequest.set_data(data);
            talkRequest.set_meta("c++");
            if (!writer->Write(talkRequest)) {
                // Broken stream.
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
        }
        writer->WritesDone();
        Status status = writer->Finish();
        if (status.ok()) {
            printResponse(talkResponse);
        } else {
            LOG(INFO) << "Error:" << status.error_code() << ": " << status.error_message();
        }
    }

    void TalkBidirectional() {
        ClientContext context;
        TalkResponse talkResponse;
        std::shared_ptr<ClientReaderWriter<TalkRequest, TalkResponse>> stream(client->TalkBidirectional(&context));
        std::thread writer([stream]() {
            std::vector<TalkRequest> request_list;
            for (int i = 0; i < 3; ++i) {
                TalkRequest talkRequest;
                string data = grpc::to_string(hello::Utils::Random(5));
                talkRequest.set_data(data);
                talkRequest.set_meta("c++");
                request_list.push_back(talkRequest);
            }
            for (const TalkRequest &talkRequest: request_list) {
                stream->Write(talkRequest);
            }
            stream->WritesDone();
        });
        while (stream->Read(&talkResponse)) {
            printResponse(talkResponse);
        }
        writer.join();
        Status status = stream->Finish();
        if (!status.ok()) {
            LOG(INFO) << "Error:" << status.error_code() << ": " << status.error_message();
        }
    }

    void printResponse(TalkResponse response) {
        const RepeatedPtrField<TalkResult> &talkResults = response.results();
        for (TalkResult result: talkResults) {
            const Map<string, string> &kv = result.kv();
            string id(kv.at("id"));
            string idx(kv.at("idx"));
            string meta(kv.at("meta"));
            string data(kv.at("data"));
            LOG(INFO) << response.status()
                      << " " << result.id()
                      << " [" << meta
                      << " " << ResultType_Name(result.type())
                      << " " << id
                      << " " << idx
                      << " " << data
                      << "]";
        }
    }

private:
    std::unique_ptr<LandingService::Stub> client;
};

int main(int argc, char **argv) {
    /*日志文件名 <program name>.<host name>.<user name>.log.<Severity level>.<date>-<time>.<pid> */
    google::InitGoogleLogging(argv[0]);
    google::SetLogDestination(google::INFO, "/Users/han/hello_grpc/");
    FLAGS_colorlogtostderr = true;
    FLAGS_alsologtostderr = 1;

    LOG(INFO) << "Hello gRPC C++ Client is starting...";

    // Instantiate the client. It requires a channel, out of which the actual RPCs
    // are created. This channel models a connection to an endpoint specified by
    // the argument "--target=" which is the only expected argument.
    // We indicate that the channel isn't authenticated (use of
    // InsecureChannelCredentials()).
    std::string target_str;
    std::string arg_str("--target");
    if (argc > 1) {
        std::string arg_val = argv[1];
        size_t start_pos = arg_val.find(arg_str);
        if (start_pos != std::string::npos) {
            start_pos += arg_str.size();
            if (arg_val[start_pos] == '=') {
                target_str = arg_val.substr(start_pos + 1);
            } else {
                LOG(INFO) << "The only correct argument syntax is --target=";
                return 0;
            }
        } else {
            LOG(INFO) << "The only acceptable argument is --target=";
            return 0;
        }
    } else {
        target_str = "localhost:9996";
    }
    const std::shared_ptr<Channel> &channel = grpc::CreateChannel(target_str, grpc::InsecureChannelCredentials());
    //
    LandingClient landingClient(channel);
    LOG(INFO) << "Unary RPC";
    landingClient.Talk();
    LOG(INFO) << "Server streaming RPC";
    landingClient.TalkOneAnswerMore();
    LOG(INFO) << "Client streaming RPC";
    landingClient.TalkMoreAnswerOne();
    LOG(INFO) << "Bidirectional streaming RPC";
    landingClient.TalkBidirectional();
    LOG(WARNING) << "Hello gRPC C++ Client is stopping";
    google::ShutdownGoogleLogging();
    return 0;
}
