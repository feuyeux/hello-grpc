using System;
using System.IO;
using System.Net.Http;
using System.Net.Security;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
using Grpc.Core;
using Grpc.Net.Client;
using Grpc.Net.Client.Configuration;
using log4net;

namespace Common
{
    /// <summary>
    /// Manages gRPC channel connections with support for both secure (TLS) and insecure connections.
    /// </summary>
    public static class Connection
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(Connection));
        private static readonly string CertBasePath = GetCertBasePath();
        private static readonly string CertPath = Path.Combine(CertBasePath, "cert.pem");
        private static readonly string CertKeyPath = Path.Combine(CertBasePath, "private.pkcs8.key");
        private static readonly string CertChainPath = Path.Combine(CertBasePath, "full_chain.pem");
        private static readonly string RootCertPath = Path.Combine(CertBasePath, "myssl_root.cer");
        private const string ServerName = "hello.grpc.io";

        private static string GetCertBasePath()
        {
            // Get custom base path from environment variable if set
            var basePath = Environment.GetEnvironmentVariable("CERT_BASE_PATH");
            if (!string.IsNullOrEmpty(basePath))
            {
                return basePath;
            }
            
            // Use platform-specific default paths
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                return @"d:\garden\var\hello_grpc\client_certs";
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            {
                return "/var/hello_grpc/client_certs";
            }
            else // Linux and others
            {
                return "/var/hello_grpc/client_certs";
            }
        }

        static Connection()
        {
            Log.Info($"Using certificate paths: Cert={CertPath}, CertKey={CertKeyPath}, CertChain={CertChainPath}, RootCert={RootCertPath}");
        }

        /// <summary>
        /// Retry service config for hello.LandingService following gRPC A6 client retries
        /// (https://github.com/grpc/proposal/blob/master/A6-client-retries.md).
        /// </summary>
        private static ServiceConfig BuildRetryServiceConfig()
        {
            return new ServiceConfig
            {
                MethodConfigs =
                {
                    new MethodConfig
                    {
                        Names = { new MethodName { Service = "hello.LandingService" } },
                        RetryPolicy = new RetryPolicy
                        {
                            MaxAttempts = 4,
                            InitialBackoff = TimeSpan.FromMilliseconds(100),
                            MaxBackoff = TimeSpan.FromSeconds(1),
                            BackoffMultiplier = 2,
                            RetryableStatusCodes = { StatusCode.Unavailable }
                        }
                    }
                }
            };
        }

        /// <summary>
        /// Applies HTTP/2 keepalive ping settings shared by secure and insecure channels.
        /// </summary>
        private static void ConfigureKeepalive(SocketsHttpHandler handler)
        {
            handler.KeepAlivePingDelay = TimeSpan.FromSeconds(10);
            handler.KeepAlivePingTimeout = TimeSpan.FromSeconds(1);
            handler.KeepAlivePingPolicy = HttpKeepAlivePingPolicy.Always;
            handler.EnableMultipleHttp2Connections = true;
        }

        /// <summary>
        /// Creates and returns a gRPC channel configured based on environment variables.
        /// Supports both secure (TLS) and insecure connections.
        /// </summary>
        /// <returns>A configured GrpcChannel</returns>
        public static GrpcChannel GetChannel()
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
                
                var handler = new SocketsHttpHandler
                {
                    SslOptions = new SslClientAuthenticationOptions
                    {
                        // In development environment, certificate validation can be disabled
                        RemoteCertificateValidationCallback = (sender, certificate, chain, errors) => true,
                    }
                };
                ConfigureKeepalive(handler);
                
                // Add client certificate if available
                if (File.Exists(CertPath) && File.Exists(CertKeyPath))
                {
                    try
                    {
                        // Load certificate with private key using CreateFromPemFile
                        var clientCert = X509Certificate2.CreateFromPemFile(CertPath, CertKeyPath);
                        
                        handler.SslOptions.ClientCertificates = new X509CertificateCollection { clientCert };
                        Log.Info("Client certificate loaded successfully");
                    }
                    catch (Exception ex)
                    {
                        Log.Warn($"Failed to load client certificate: {ex.Message}");
                    }
                }
                
                var channelOptions = new GrpcChannelOptions
                {
                    HttpHandler = handler,
                    ServiceConfig = BuildRetryServiceConfig()
                };
                
                return GrpcChannel.ForAddress($"https://{endpoint}", channelOptions);
            }
            
            Log.Info($"Connect with InSecure(:{port})");
            var insecureHandler = new SocketsHttpHandler();
            ConfigureKeepalive(insecureHandler);
            return GrpcChannel.ForAddress($"http://{endpoint}", new GrpcChannelOptions
            {
                HttpHandler = insecureHandler,
                ServiceConfig = BuildRetryServiceConfig()
            });
        }

        /// <summary>
        /// Gets the gRPC server host from environment variable or returns default.
        /// </summary>
        /// <returns>Server host address</returns>
        private static string GetGrcServerHost()
        {
            var server = Environment.GetEnvironmentVariable("GRPC_SERVER");
            return server ?? "localhost";
        }

        /// <summary>
        /// Gets the gRPC server port from environment variable or returns default.
        /// </summary>
        /// <returns>Server port number</returns>
        public static string GetGrcServerPort()
        {
            var server = Environment.GetEnvironmentVariable("GRPC_SERVER_PORT");
            return server ?? "9996";
        }
    }
}