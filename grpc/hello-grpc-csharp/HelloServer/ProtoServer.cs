using System;
using System.Threading;
using Grpc.Core;

namespace HelloServer
{
    internal static class ProtoServer
    {
        private static readonly ManualResetEvent Shutdown = new ManualResetEvent(false);

        private static void Main(string[] args)
        {
            const int port = 9996;
            var server = new Server
            {
                Services =
                {
                    Org.Feuyeux.Grpc.LandingService.BindService(new LandingServiceImpl())
                },
                Ports = { new ServerPort("0.0.0.0", port, ServerCredentials.Insecure) }
            };
            server.Start();

            Console.WriteLine("Start GRPC listening on port " + port);
            Shutdown.WaitOne();
            server.ShutdownAsync().Wait();
        }
    }
}