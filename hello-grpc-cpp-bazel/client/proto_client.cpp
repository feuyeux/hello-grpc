#include <iostream>
#include <memory>
#include <string>

#include "grpcpp/grpcpp.h"
#include "glog/logging.h"
#include <thread>

#include "protos/landing.grpc.pb.h"
#include "common/utils.h"
#include "common/connection.h"

using google::protobuf::Map;
using google::protobuf::RepeatedPtrField;
using grpc::Channel;
using grpc::ClientContext;
using grpc::ClientReader;
using grpc::ClientReaderWriter;
using grpc::ClientWriter;
using grpc::Status;
using hello::Connection;
using hello::Utils;
using org::feuyeux::grpc::LandingService;
using org::feuyeux::grpc::ResultType;
using org::feuyeux::grpc::TalkRequest;
using org::feuyeux::grpc::TalkResponse;
using org::feuyeux::grpc::TalkResult;
using std::string;

class LandingClient
{
public:
    explicit LandingClient(const std::shared_ptr<Channel> &channel) : client(LandingService::NewStub(channel)) {}

    void Talk()
    {
        ClientContext context;
        buildHeaders(context);
        TalkResponse talkResponse;
        TalkRequest talkRequest;
        talkRequest.set_data("1");
        talkRequest.set_meta("C++");
        Status status = client->Talk(&context, talkRequest, &talkResponse);
        if (status.ok())
        {
            printResponse(context, talkResponse);
        }
        else
        {
            LOG(INFO) << "Error:" << status.error_code() << ": " << status.error_message();
        }
    }

    void TalkOneAnswerMore()
    {
        ClientContext context;
        buildHeaders(context);
        TalkResponse talkResponse;
        TalkRequest talkRequest;
        talkRequest.set_data("1,2,3");
        talkRequest.set_meta("C++");
        const std::unique_ptr<::grpc::ClientReader<TalkResponse>>
            &response(client->TalkOneAnswerMore(&context, talkRequest));
        while (response->Read(&talkResponse))
        {
            printResponse(context, talkResponse);
        }
    }

    void TalkMoreAnswerOne()
    {
        ClientContext context;
        buildHeaders(context);
        TalkResponse talkResponse;
        std::unique_ptr<ClientWriter<TalkRequest>> writer(client->TalkMoreAnswerOne(&context, &talkResponse));
        const list<TalkRequest> &requests = Utils::buildLinkRequests();
        for (auto &&request : requests)
        {
            if (!writer->Write(request))
            {
                // Broken stream.
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
        }
        writer->WritesDone();
        Status status = writer->Finish();
        if (status.ok())
        {
            printResponse(context, talkResponse);
        }
        else
        {
            LOG(INFO) << "Error:" << status.error_code() << ": " << status.error_message();
        }
    }

    void TalkBidirectional()
    {
        ClientContext context;
        buildHeaders(context);
        TalkResponse talkResponse;
        std::shared_ptr<ClientReaderWriter<TalkRequest, TalkResponse>> stream(client->TalkBidirectional(&context));
        std::thread writer([stream]()
                           {
            const list<TalkRequest> &requests = Utils::buildLinkRequests();
            for (auto &&request: requests) {
                stream->Write(request);
            }
            stream->WritesDone(); });
        while (stream->Read(&talkResponse))
        {
            printResponse(context, talkResponse);
        }
        writer.join();
        Status status = stream->Finish();
        if (!status.ok())
        {
            LOG(INFO) << "Error:" << status.error_code() << ": " << status.error_message();
        }
    }

    static void printResponse(ClientContext &context, const TalkResponse &response)
    {
        const multimap<grpc::string_ref, grpc::string_ref> &headers = context.GetServerInitialMetadata();
        for (const auto &header : headers)
        {
            LOG(INFO) << "<-H " << header.first << ":" << header.second;
        }
        const RepeatedPtrField<TalkResult> &talkResults = response.results();
        for (const TalkResult &result : talkResults)
        {
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
        const multimap<grpc::string_ref, grpc::string_ref> &tails = context.GetServerTrailingMetadata();
        for (const auto &tail : tails)
        {
            LOG(INFO) << "<-L " << tail.first << ":" << tail.second;
        }
    }

    static void buildHeaders(ClientContext &context)
    {
        // examples/cpp/metadata
        context.AddMetadata("k1", "v1");
        context.AddMetadata("k2", "v2");
    }

private:
    std::unique_ptr<LandingService::Stub> client;
};

int main(__attribute__((unused)) int argc, char **argv)
{
    Utils::initLog(argv);
    LandingClient landingClient(Connection::getChannel());
    LOG(INFO) << "Unary RPC";
    landingClient.Talk();
    LOG(INFO) << "Server streaming RPC";
    landingClient.TalkOneAnswerMore();
    LOG(INFO) << "Client streaming RPC";
    landingClient.TalkMoreAnswerOne();
    LOG(INFO) << "Bidirectional streaming RPC";
    landingClient.TalkBidirectional();
    google::ShutdownGoogleLogging();
    return 0;
}