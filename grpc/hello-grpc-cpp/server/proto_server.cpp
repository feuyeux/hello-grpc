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
__attribute__((unused)) const char cert[] = "/var/hello_grpc/server_certs/cert.pem";
const char certKey[] = "/var/hello_grpc/server_certs/private.key";
const char certChain[] = "/var/hello_grpc/server_certs/full_chain.pem";
const char rootCert[] = "/var/hello_grpc/server_certs/myssl_root.cer";

class LandingServiceImpl final : public LandingService::Service {
public:
    Status Talk(ServerContext *context, const TalkRequest *request, TalkResponse *response) override {
        if (client != nullptr) {
            grpc::ClientContext c;
            propagateHeaders(context, c);
            return client->Talk(&c, *request, response);
        } else {
            printHeaders(context);
            context->AddInitialMetadata("h1", "v1");
            context->AddTrailingMetadata("l1", "v1");
            const string &id = request->data();
            LOG(INFO) << "TALK REQUEST: data=" << id << ", meta=" << request->meta();
            response->set_status(200);
            TalkResult *talkResult;
            talkResult = response->add_results();
            buildResult(id, talkResult);
            return Status::OK;
        }
    }

    Status
    TalkOneAnswerMore(ServerContext *context, const TalkRequest *request,
                      ServerWriter<TalkResponse> *writer) override {
        printHeaders(context);
        if (client != nullptr) {
            grpc::ClientContext c;
            propagateHeaders(context, c);
            TalkResponse talkResponse;
            const std::unique_ptr<::grpc::ClientReader<TalkResponse>>
                    &response(client->TalkOneAnswerMore(&c, *request));
            while (response->Read(&talkResponse)) {
                writer->Write(talkResponse);
            }
        } else {
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
        }
        return Status::OK;
    }

    Status
    TalkMoreAnswerOne(ServerContext *context, ServerReader<TalkRequest> *reader, TalkResponse *response) override {
        printHeaders(context);
        if (client != nullptr) {
            grpc::ClientContext c;
            propagateHeaders(context, c);
            std::unique_ptr<grpc::ClientWriter<TalkRequest>> writer(client->TalkMoreAnswerOne(&c, response));
            TalkRequest request;
            while (reader->Read(&request)) {
                if (!writer->Write(request)) {
                    // Broken stream.
                    break;
                }
            }
            writer->WritesDone();
            return writer->Finish();
        } else {
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
    }

    Status TalkBidirectional(ServerContext *context, ServerReaderWriter<TalkResponse, TalkRequest> *stream) override {
        printHeaders(context);
        if (client != nullptr) {
            grpc::ClientContext c;
            propagateHeaders(context, c);
            TalkResponse talkResponse;
            std::shared_ptr<grpc::ClientReaderWriter<TalkRequest, TalkResponse>> s(client->TalkBidirectional(&c));
            TalkRequest request;
            while (stream->Read(&request)) {
                s->Write(request);
            }
            while (s->Read(&talkResponse)) {
                stream->Write(talkResponse);
            }
            return s->Finish();
        } else {
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
    }

    void buildResult(const string &id, TalkResult *talkResult) {
        talkResult->set_id(Utils::now());
        talkResult->set_type(ResultType::OK);
        google::protobuf::Map<string, string> *pMap = talkResult->mutable_kv();
        int index = stoi(id);
        (*pMap)["id"] = "UUID-TODO";
        (*pMap)["idx"] = id;
        (*pMap)["meta"] = "C++";
        const string &hello = Utils::hello(index);
        (*pMap)["data"] = hello + "," + Utils::thanks(hello);
    }

    static void printHeaders(const ServerContext *context) {
        const multimap<grpc::string_ref, grpc::string_ref> &metadata = context->client_metadata();
        for (const auto &iter: metadata) {
            const grpc::string_ref &key = iter.first;
            const grpc::string_ref &value = iter.second;
            LOG(INFO) << "->H " << key << ":" << value;
        }
    }

    static void propagateHeaders(const ServerContext *context, grpc::ClientContext &c) {
        const multimap<grpc::string_ref, grpc::string_ref> &metadata = context->client_metadata();
        for (const auto &iter: metadata) {
            const grpc::string_ref &key = iter.first;
            const grpc::string_ref &value = iter.second;
            LOG(INFO) << "->H " << key << ":" << value;
            //c.AddMetadata((basic_string<char> &&) key, (basic_string<char> &&) value);
        }
    }

    void setChannel(const std::shared_ptr<Channel> &channel) {
        if (channel != nullptr) {
            client = LandingService::NewStub(channel);
        }
    }

private:
    std::unique_ptr<LandingService::Stub> client;
};

void RunServer() {
    const string &port = Utils::getServerPort();
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
        pemKeyCertPair.private_key = Connection::getFileContent(certKey);
        pemKeyCertPair.cert_chain = Connection::getFileContent(certChain);
        ssl_opts.pem_key_cert_pairs.push_back({pemKeyCertPair});
        builder.AddListeningPort(server_address, grpc::SslServerCredentials(ssl_opts));
    } else {
        LOG(INFO) << "Start GRPC Server[" << port << "]";
        builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
    }

    LandingServiceImpl landingService;
    const char *backend = getenv("GRPC_HELLO_BACKEND");
    string endpoint(backend ? backend : "");
    if (!endpoint.empty()) {
        landingService.setChannel(Connection::getChannel());
    }
    builder.RegisterService(&landingService);
    std::unique_ptr<Server> server(builder.BuildAndStart());
    LOG(INFO) << "Server listening on " << server_address;
    server->Wait();
}

int main(__attribute__((unused)) int argc, char **argv) {
    Utils::initLog(argv);
    RunServer();
    LOG(WARNING) << "Hello gRPC C++ Server is stopping";
    google::ShutdownGoogleLogging();
    return 0;
}

//TODO UUID https://github.com/r-lyeh-archived/sole
