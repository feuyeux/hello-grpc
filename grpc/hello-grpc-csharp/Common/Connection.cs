using System;
using System.Collections.Generic;
using System.IO;
using Grpc.Core;
using log4net;

namespace Common
{
    public static class Connection
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(Connection));
        private const string Cert = @"/var/hello_grpc/client_certs/cert.pem";
        private const string CertKey = @"/var/hello_grpc/client_certs/private.pkcs8.key";
        private const string CertChain = @"/var/hello_grpc/client_certs/full_chain.pem";
        private const string RootCert = @"/var/hello_grpc/client_certs/myssl_root.cer";
        private const string ServerName = "hello.grpc.io";

        public static Channel GetChannel()
        {
            var backPort = Environment.GetEnvironmentVariable("GRPC_HELLO_BACKEND_PORT");
            var port = backPort ?? GetGrcServerPort();
            var backServer = Environment.GetEnvironmentVariable("GRPC_HELLO_BACKEND");
            var connectTo = backServer ?? GetGrcServerHost();
            var endpoint = connectTo + ":" + port;
            var tls = Environment.GetEnvironmentVariable("GRPC_HELLO_SECURE");
            if (tls is "Y")
            {
                Log.Info($"Connect with TLS(:{port})");
                //TODO
                var options = new List<ChannelOption>
                {
                    new ChannelOption(ChannelOptions.SslTargetNameOverride, ServerName)
                };
                // return new Channel(connectTo,int.Parse(port), BuildSslCredentials(), options);
                return new Channel(connectTo,int.Parse(port), new SslCredentials(), options);
            }
            Log.Info($"Connect with InSecure(:{port})");
            return new Channel(endpoint, ChannelCredentials.Insecure);
        }

        private static ChannelCredentials BuildSslCredentials()
        {
            var rootCertFile = File.ReadAllText(RootCert);
            var certChainFile = File.ReadAllText(CertChain);
            var certKeyFile = File.ReadAllText(CertKey);
            var sslCredentials = new SslCredentials(rootCertFile, new KeyCertificatePair(certChainFile,certKeyFile));
            Log.Info($"{sslCredentials.GetType().Name}");
            return sslCredentials;
        }

        private static string GetGrcServerHost()
        {
            var server = Environment.GetEnvironmentVariable("GRPC_SERVER");
            return server ?? "localhost";
        }

        public static string GetGrcServerPort()
        {
            var server = Environment.GetEnvironmentVariable("GRPC_SERVER_PORT");
            return server ?? "9996";
        }
    }
}