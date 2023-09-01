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
                var options = new List<ChannelOption>
                {
                    new ChannelOption(ChannelOptions.DefaultAuthority, ServerName)
                };
                return new Channel(connectTo,int.Parse(port), BuildSslCredentials(), options);
            }
            Log.Info($"Connect with InSecure(:{port})");
            return new Channel(endpoint, ChannelCredentials.Insecure);
        }

        private static ChannelCredentials BuildSslCredentials()
        {
            // ssl_opts.pem_root_certs = Connection::getFileContent(certChain);
            // ssl_opts.pem_private_key = Connection::getFileContent(certKey).c_str();
            // ssl_opts.pem_cert_chain = Connection::getFileContent(certChain).c_str();
            
            var certChainFile = File.ReadAllText(CertChain);
            var certKeyFile = File.ReadAllText(CertKey);
            var sslCredentials = new SslCredentials(certChainFile, new KeyCertificatePair(certChainFile,certKeyFile));
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