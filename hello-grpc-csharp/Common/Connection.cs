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
    public static class Connection
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(Connection));
        private static readonly string CertBasePath = GetCertBasePath();
        private static readonly string Cert = Path.Combine(CertBasePath, "cert.pem");
        private static readonly string CertKey = Path.Combine(CertBasePath, "private.pkcs8.key");
        private static readonly string CertChain = Path.Combine(CertBasePath, "full_chain.pem");
        private static readonly string RootCert = Path.Combine(CertBasePath, "myssl_root.cer");
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
            Log.Info($"Using certificate paths: Cert={Cert}, CertKey={CertKey}, CertChain={CertChain}, RootCert={RootCert}");
        }

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
                        // 在开发环境中可以禁用证书验证
                        RemoteCertificateValidationCallback = (sender, certificate, chain, errors) => true,
                        // 如果需要更严格的证书验证，可以使用以下代码
                        // ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
                    }
                };
                
                // 如果有客户端证书，可以在这里添加
                if (File.Exists(Cert) && File.Exists(CertKey))
                {
                    try
                    {
                        // Load certificate with private key using modern methods
                        X509Certificate2 clientCert;
                        
                        if (File.Exists(CertKey))
                        {
                            // Load certificate and private key separately
                            var privateKeyBytes = File.ReadAllBytes(CertKey);
                            var certBytes = File.ReadAllBytes(Cert);
                            clientCert = LoadCertificateWithPrivateKey(certBytes, privateKeyBytes);
                        }
                        else
                        {
                            // Fallback to old method if needed
                            clientCert = X509Certificate2.CreateFromPemFile(Cert);
                        }
                        
                        handler.SslOptions.ClientCertificates = new X509CertificateCollection { clientCert };
                    }
                    catch (Exception ex)
                    {
                        Log.Warn($"加载客户端证书失败: {ex.Message}");
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

        // 不再需要这个方法，但为了保持代码结构完整性我们保留它的签名
        private static HttpMessageHandler BuildSslHandler()
        {
            var handler = new SocketsHttpHandler
            {
                SslOptions = new SslClientAuthenticationOptions
                {
                    // 开发环境中简化证书验证
                    RemoteCertificateValidationCallback = (sender, certificate, chain, errors) => true
                }
            };
            
            return handler;
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

        private static X509Certificate2 LoadCertificateWithPrivateKey(byte[] certBytes, byte[] privateKeyBytes)
        {
            // This method creates an X509Certificate2 with the private key loaded
            try
            {
                // In .NET, we need to use platform-specific approaches depending on the runtime
                if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                {
                    // On Windows, import with appropriate flags
                    // Create a temporary file for the certificate
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
                    // On Linux/macOS
                    // Create temporary files for the certificate and key
                    string tempCertPath = Path.GetTempFileName();
                    try
                    {
                        File.WriteAllBytes(tempCertPath, certBytes);
                        var cert = X509Certificate2.CreateFromPemFile(tempCertPath);
                        
                        // Import the private key
                        var privateKey = System.Security.Cryptography.RSA.Create();
                        privateKey.ImportPkcs8PrivateKey(privateKeyBytes, out _);
                        
                        // Create a new certificate with the private key
                        var certWithKey = cert.CopyWithPrivateKey(privateKey);
                        
                        // Return the certificate with key using appropriate flags for Linux/macOS
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