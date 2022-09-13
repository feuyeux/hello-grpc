#include <string>
#include <fstream>
#include <grpcpp/grpcpp.h>
#include <glog/logging.h>
#include "connection.h"
#include "utils.h"

using grpc::Channel;

namespace hello {
    string Connection::getFileContent(const char *path) {
        std::ifstream stream(path);
        std::string contents;
        contents.assign((std::istreambuf_iterator<char>(stream)), std::istreambuf_iterator<char>());
        stream.close();
        return contents;
    }

    shared_ptr<Channel> Connection::getChannel() {
        //https://myssl.com/create_test_cert.html
        const char cert[] = "/var/hello_grpc/client_certs/cert.pem";
        const char certKey[] = "/var/hello_grpc/client_certs/private.key";
        const char certChain[] = "/var/hello_grpc/client_certs/full_chain.pem";
        const char rootCert[] = "/var/hello_grpc/client_certs/myssl_root.cer";
        const string serverName = "hello.grpc.io";

        const string &port = Utils::getBackendPort();
        const basic_string<char, char_traits<char>, allocator<char>> &target = Utils::getBackend() + ":" + port;
        const string &secure = Utils::getSecure();
        if (!secure.empty() && secure == "Y") {
            grpc::SslCredentialsOptions ssl_opts;
            ssl_opts.pem_root_certs = Connection::getFileContent(certChain);
            ssl_opts.pem_private_key = Connection::getFileContent(certKey);
            ssl_opts.pem_cert_chain = Connection::getFileContent(certChain);
            grpc::ChannelArguments channel_args;
            channel_args.SetString("grpc.default_authority", serverName);
            LOG(INFO) << "Connect with TLS(" << port << ")";
            return grpc::CreateCustomChannel(target, grpc::SslCredentials(ssl_opts), channel_args);
        } else {
            LOG(INFO) << "Connect with InSecure(" << port << ")";
            return grpc::CreateChannel(target, grpc::InsecureChannelCredentials());
        }
    }
}
