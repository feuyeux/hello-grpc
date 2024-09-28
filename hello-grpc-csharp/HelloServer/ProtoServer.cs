using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Threading;
using Common;
using Grpc.Core;
using log4net;
using log4net.Config;
using Org.Feuyeux.Grpc;

[assembly: XmlConfigurator(Watch = true)]

namespace HelloServer
{
    internal static class ProtoServer
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(ProtoServer));

        private static readonly ManualResetEvent Shutdown = new ManualResetEvent(false);

        private const string Cert = @"/var/hello_grpc/server_certs/cert.pem";
        private const string CertKey = @"/var/hello_grpc/server_certs/private.pkcs8.key";
        private const string CertChain = @"/var/hello_grpc/server_certs/full_chain.pem";
        private const string RootCert = @"/var/hello_grpc/server_certs/myssl_root.cer";

        private static void Main()
        {
            // https://logging.apache.org/log4net/release/manual/configuration.html
            var logRepository = LogManager.GetRepository(Assembly.GetEntryAssembly() ?? throw new InvalidOperationException());
            XmlConfigurator.Configure(logRepository, new FileInfo("log4net.config"));
            var port = Connection.GetGrcServerPort();
            var tls = Environment.GetEnvironmentVariable("GRPC_HELLO_SECURE");
            var backServer = Environment.GetEnvironmentVariable("GRPC_HELLO_BACKEND");
            Server server;
            var landingServiceImpl = new LandingServiceImpl();
            if (backServer != null)
            {
                var channel = Connection.GetChannel();
                landingServiceImpl.SetProtoClient(new LandingService.LandingServiceClient(channel));
            }
            if (tls is "Y")
            {
                var rootCertFile = File.ReadAllText(RootCert);
                var certChainFile = File.ReadAllText(CertChain);
                var certKeyFile = File.ReadAllText(CertKey);
                var keypair = new KeyCertificatePair(certChainFile, certKeyFile);
                var sslCredentials = new SslServerCredentials(
                    new List<KeyCertificatePair>() { keypair },
                    rootCertFile,
                    SslClientCertificateRequestType.RequestAndRequireButDontVerify);
                server = new Server
                {
                    Services =
                    {
                        LandingService.BindService(landingServiceImpl)
                    },
                    Ports = { new ServerPort("0.0.0.0", int.Parse(port), sslCredentials) }
                };
                Log.Info($"Start GRPC TLS Server[:{port}]");
            }
            else
            {
                server = new Server
                {
                    Services =
                    {
                        LandingService.BindService(landingServiceImpl)
                    },
                    Ports = { new ServerPort("0.0.0.0", int.Parse(port), ServerCredentials.Insecure) }
                };
                Log.Info($"Start GRPC Server[:{port}]");
            }
            server.Start();
            Shutdown.WaitOne();
            server.ShutdownAsync().Wait();
        }
    }
}