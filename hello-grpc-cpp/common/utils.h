using namespace std;

#include "protos/landing.grpc.pb.h"

using hello::TalkRequest;

#include <list>

namespace hello {
    class Utils {
    public:
        static string hello(int index);

        static string uuid();

        static string thanks(string key);

        static list<TalkRequest> buildLinkRequests();

        static void initLog(char *const *argv);

        static int random(int n);

        static long now();

        static string getServerHost();

        static string getServerPort();

        static string getBackend();

        static string getBackendPort();

        static string getSecure();
    };
}
