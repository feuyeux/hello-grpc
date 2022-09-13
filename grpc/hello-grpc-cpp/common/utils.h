using namespace std;

namespace hello {
    class Utils {
    public:
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
