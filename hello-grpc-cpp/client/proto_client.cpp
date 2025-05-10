#include <iostream>
#include <memory>
#include <string>
#include <thread>

#include "glog/logging.h"
#include "grpcpp/grpcpp.h"

#include "common/connection.h"
#include "common/utils.h"
#include "protos/landing.grpc.pb.h"

using google::protobuf::Map;
using google::protobuf::RepeatedPtrField;
using grpc::Channel;
using grpc::ClientContext;
using grpc::ClientReader;
using grpc::ClientReaderWriter;
using grpc::ClientWriter;
using grpc::Status;
using hello::Connection;
using hello::LandingService;
using hello::ResultType;
using hello::TalkRequest;
using hello::TalkResponse;
using hello::TalkResult;
using hello::Utils;

class LandingClient {
public:
  // 显式构造函数，使用现代初始化语法
  explicit LandingClient(std::shared_ptr<Channel> channel)
      : client_(LandingService::NewStub(std::move(channel))) {}

  void Talk() {
    ClientContext context;
    buildHeaders(context);

    TalkResponse talkResponse;
    TalkRequest talkRequest;
    talkRequest.set_data("1");
    talkRequest.set_meta("C++");

    Status status = client_->Talk(&context, talkRequest, &talkResponse);
    if (status.ok()) {
      printResponse(context, talkResponse);
    } else {
      LOG(INFO) << "Error:" << status.error_code() << ": "
                << status.error_message();
    }
  }

  void TalkOneAnswerMore() {
    ClientContext context;
    buildHeaders(context);

    TalkRequest talkRequest;
    talkRequest.set_data("1,2,3");
    talkRequest.set_meta("C++");

    auto response = client_->TalkOneAnswerMore(&context, talkRequest);

    TalkResponse talkResponse;
    while (response->Read(&talkResponse)) {
      printResponse(context, talkResponse);
    }
  }

  void TalkMoreAnswerOne() {
    ClientContext context;
    buildHeaders(context);

    TalkResponse talkResponse;
    auto writer = client_->TalkMoreAnswerOne(&context, &talkResponse);

    const auto &requests = Utils::buildLinkRequests();
    for (const auto &request : requests) {
      if (!writer->Write(request)) {
        // 流已断开
        break;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }

    writer->WritesDone();
    Status status = writer->Finish();

    if (status.ok()) {
      printResponse(context, talkResponse);
    } else {
      LOG(INFO) << "Error:" << status.error_code() << ": "
                << status.error_message();
    }
  }

  void TalkBidirectional() {
    ClientContext context;
    buildHeaders(context);

    auto stream = client_->TalkBidirectional(&context);

    // 使用 lambda 表达式和更现代的线程用法
    std::thread writer([&stream]() {
      const auto &requests = Utils::buildLinkRequests();
      for (const auto &request : requests) {
        stream->Write(request);
      }
      stream->WritesDone();
    });

    TalkResponse talkResponse;
    while (stream->Read(&talkResponse)) {
      printResponse(context, talkResponse);
    }

    writer.join();
    Status status = stream->Finish();

    if (!status.ok()) {
      LOG(INFO) << "Error:" << status.error_code() << ": "
                << status.error_message();
    }
  }

  static void printResponse(ClientContext &context,
                            const TalkResponse &response) {
    // 打印服务器初始元数据
    const auto &headers = context.GetServerInitialMetadata();
    for (const auto &[first, second] : headers) {
      LOG(INFO) << "<-H " << first << ":" << second;
    }

    // 打印结果
    const auto &talkResults = response.results();
    for (const auto &result : talkResults) {
      const auto &kv = result.kv();
      try {
        const auto &id = kv.at("id");
        const auto &idx = kv.at("idx");
        const auto &meta = kv.at("meta");
        const auto &data = kv.at("data");

        LOG(INFO) << response.status() << " " << result.id() << " [" << meta
                  << " " << ResultType_Name(result.type()) << " " << id << " "
                  << idx << " " << data << "]";
      } catch (const std::out_of_range &e) {
        LOG(ERROR) << "Missing required key in response: " << e.what();
      }
    }

    // 打印服务器尾部元数据
    const auto &tails = context.GetServerTrailingMetadata();
    for (const auto &[first, second] : tails) {
      LOG(INFO) << "<-L " << first << ":" << second;
    }
  }

  static void buildHeaders(ClientContext &context) {
    context.AddMetadata("k1", "v1");
    context.AddMetadata("k2", "v2");
  }

private:
  std::unique_ptr<LandingService::Stub> client_; // 使用尾部下划线表示私有成员
};

int main(int argc, char **argv) {
  Utils::initLog(argv);

  // 创建客户端并执行不同类型的 RPC 调用
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