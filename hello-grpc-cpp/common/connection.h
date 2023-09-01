using namespace std;
using grpc::Channel;

namespace hello {
    class Connection {
    public:
        static string getFileContent(const char *path);

        static shared_ptr<Channel> getChannel();
    };
}
