using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Security;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
using Grpc.Net.Client;
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
                
                // Add client certificate if available
                if (File.Exists(CertPath) && File.Exists(CertKeyPath))
                {
                    try
                    {
                        // Load certificate with private key
                        var privateKeyBytes = File.ReadAllBytes(CertKeyPath);
                        var certBytes = File.ReadAllBytes(CertPath);
                        var clientCert = LoadCertificateWithPrivateKey(certBytes, privateKeyBytes);
                        
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
                    HttpHandler = handler
                };
                
                return GrpcChannel.ForAddress($"https://{endpoint}", channelOptions);
            }
            
            Log.Info($"Connect with InSecure(:{port})");
            return GrpcChannel.ForAddress($"http://{endpoint}");
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

        /// <summary>
        /// Loads an X509Certificate2 with its private key from PEM-formatted bytes.
        /// Handles platform-specific certificate loading requirements.
        /// </summary>
        /// <param name="certBytes">The certificate bytes</param>
        /// <param name="privateKeyBytes">The private key bytes in PKCS8 format</param>
        /// <returns>An X509Certificate2 with private key loaded</returns>
        private static X509Certificate2 LoadCertificateWithPrivateKey(byte[] certBytes, byte[] privateKeyBytes)
        {
            try
            {
                // Use platform-specific approaches depending on the runtime
                if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                {
                    // Windows-specific certificate handling
                    string tempCertPath = Path.GetTempFileName();
                    try
                    {
                        File.WriteAllBytes(tempCertPath, certBytes);
                        var cert = X509Certificate2.CreateFromPemFile(tempCertPath);
                        var rsa = System.Security.Cryptography.RSA.Create();
                        rsa.ImportPkcs8PrivateKey(privateKeyBytes, out _);
                        return cert.CopyWithPrivateKey(rsa);
                    }
                    finally
                    {
                        if (File.Exists(tempCertPath))
                            File.Delete(tempCertPath);
                    }
                }
                else
                {
                    // Linux/macOS certificate handling
                    string tempCertPath = Path.GetTempFileName();
                    try
                    {
                        File.WriteAllBytes(tempCertPath, certBytes);
                        var cert = X509Certificate2.CreateFromPemFile(tempCertPath);
                        
                        // Import the private key
                        var privateKey = System.Security.Cryptography.RSA.Create();
                        privateKey.ImportPkcs8PrivateKey(privateKeyBytes, out _);
                        
                        // Create certificate with the private key
                        var certWithKey = cert.CopyWithPrivateKey(privateKey);
                        
                        // Return the certificate with appropriate flags for Linux/macOS
                        return new X509Certificate2(certWithKey.Export(X509ContentType.Pfx), 
                            string.Empty, 
                            X509KeyStorageFlags.Exportable);
                    }
                    finally
                    {
                        if (File.Exists(tempCertPath))
                            File.Delete(tempCertPath);
                    }
                }
            }
            catch (Exception ex)
            {
                Log.Error($"Error loading certificate with private key: {ex.Message}");
                throw;
            }
        }
    }
}