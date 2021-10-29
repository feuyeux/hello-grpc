using namespace std;

namespace hello {
    class Utils {
    public:
        static void initLog(char *const *argv);

        static int random(int n);

        static long now();

        static string getGrcServerHost();

        static string getGrcServerPort();

        static string getBackend();

        static string getSecure();
    };
}
