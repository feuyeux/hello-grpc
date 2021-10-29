#include <iostream>
#include <memory>
#include <string>

#include <grpcpp/grpcpp.h>
#include "landing.grpc.pb.h"
#include <glog/logging.h>
#include <thread>
#include "connection.h"
#include "utils.h"

using grpc::Channel;
using grpc::ClientContext;
using grpc::Status;
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
using hello::Connection;
using hello::Utils;

class LandingClient {
public:
    LandingClient(std::shared_ptr<Channel> channel) : client(LandingService::NewStub(channel)) {}

    void Talk() {
        // Context for the client. It could be used to convey extra information to
        // the server and/or tweak certain RPC behaviors.
        ClientContext context;

        // Setting custom metadata to be sent to the server
        context.AddMetadata("custom-header", "Custom Value");

        // Setting custom binary metadata
        char bytes[8] = {'\0', '\1', '\2', '\3', '\4', '\5', '\6', '\7'};
        context.AddMetadata("custom-bin", std::string(bytes, 8));

        TalkResponse talkResponse;
        TalkRequest talkRequest;
        talkRequest.set_data("1");
        talkRequest.set_meta("C++");
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
        talkRequest.set_meta("C++");
        const std::unique_ptr<::grpc::ClientReader<TalkResponse>>
                &response(
                client->TalkOneAnswerMore(&context, talkRequest));
        while (response->Read(&talkResponse)) {
            printResponse(talkResponse);
        }
    }

    void TalkMoreAnswerOne() {
        ClientContext context;
        TalkResponse talkResponse;
        std::unique_ptr<ClientWriter<TalkRequest>> writer(
                client->TalkMoreAnswerOne(&context, &talkResponse));
        TalkRequest talkRequest;
        for (int i = 0; i < 3; ++i) {
            string data = grpc::to_string(hello::Utils::random(5));
            //std::to_string
            talkRequest.set_data(data);
            talkRequest.set_meta("C++");
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
                string data = grpc::to_string(hello::Utils::random(5));
                talkRequest.set_data(data);
                talkRequest.set_meta("C++");
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
    Utils::initLog(argv);
    shared_ptr<Channel> channel = Connection::getChannel();
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