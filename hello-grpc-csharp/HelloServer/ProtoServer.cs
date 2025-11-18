using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Security;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
using System.Threading;
using System.Threading.Tasks;
using Common;
using Grpc.AspNetCore.Server;
using Grpc.Net.Client;
using Hello;
using log4net;
using log4net.Config;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

[assembly: XmlConfigurator(Watch = true)]

namespace HelloServer
{
    /// <summary>
    /// gRPC server implementation using ASP.NET Core.
    /// Supports both secure (TLS) and insecure connections.
    /// </summary>
    internal static class ProtoServer
    {
        private static readonly ILog Logger = LogManager.GetLogger(typeof(ProtoServer));
        private static readonly ManualResetEvent ShutdownEvent = new ManualResetEvent(false);

        // Certificate paths
        private static readonly string CertBasePath = GetCertBasePath();
        private static readonly string CertPath = Path.Combine(CertBasePath, "cert.pem");
        private static readonly string CertKeyPath = Path.Combine(CertBasePath, "private.pkcs8.key");
        private static readonly string CertChainPath = Path.Combine(CertBasePath, "full_chain.pem");
        private static readonly string RootCertPath = Path.Combine(CertBasePath, "myssl_root.cer");

        /// <summary>
        /// Determines the base directory for TLS certificates based on environment
        /// variable or OS-specific default paths.
        /// </summary>
        /// <returns>The base directory path where certificates are stored.</returns>
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
                return @"d:\garden\var\hello_grpc\server_certs";
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            {
                return "/var/hello_grpc/server_certs";
            }
            else // Linux and others
            {
                return "/var/hello_grpc/server_certs";
            }
        }

        /// <summary>
        /// Starts an ASP.NET Core gRPC server with the specified configuration.
        /// </summary>
        /// <param name="port">Port number to listen on</param>
        /// <param name="useTls">Whether to use TLS encryption</param>
        /// <param name="landingServiceImpl">Service implementation to handle requests</param>
        /// <returns>A task representing the asynchronous operation</returns>
        private static async Task RunGrpcServerAsync(int port, bool useTls, LandingServiceImpl landingServiceImpl)
        {
            try
            {
                var builder = WebApplication.CreateBuilder();

                // Add gRPC services
                builder.Services.AddGrpc();

                // Register service implementation as singleton
                builder.Services.AddSingleton(landingServiceImpl);

                // Configure Kestrel server
                builder.WebHost.ConfigureKestrel(options =>
                {
                    options.ListenAnyIP(port, listenOptions =>
                    {
                        listenOptions.Protocols = HttpProtocols.Http2;

                        if (useTls)
                        {
                            try
                            {
                                if (File.Exists(CertPath) && File.Exists(CertKeyPath))
                                {
                                    try
                                    {
                                        // Load certificate and key for server
                                        var privateKeyBytes = File.ReadAllBytes(CertKeyPath);
                                        var certBytes = File.ReadAllBytes(CertPath);

                                        // Use helper method to load the certificate with its private key
                                        var serverCert = LoadCertificateWithPrivateKey(certBytes, privateKeyBytes);

                                        listenOptions.UseHttps(serverCert);
                                        Logger.Info($"TLS certificate configured: {CertPath}");
                                    }
                                    catch (Exception ex)
                                    {
                                        Logger.Error($"Failed to load certificate: {ex.Message}");
                                        Logger.Warn("Falling back to development certificate");
                                        listenOptions.UseHttps();
                                    }
                                }
                                else
                                {
                                    Logger.Warn($"TLS certificate files not found, using development certificate");
                                    listenOptions.UseHttps();
                                }
                            }
                            catch (Exception ex)
                            {
                                Logger.Error($"TLS configuration failed, using insecure connection: {ex.Message}");
                                listenOptions.Protocols = HttpProtocols.Http2;
                            }
                        }
                    });
                });

                var app = builder.Build();

                // Map gRPC service
                app.MapGrpcService<LandingServiceImpl>();

                Logger.Info($"ASP.NET Core gRPC server listening on http{(useTls ? "s" : "")}://0.0.0.0:{port}");

                // Start the server without waiting
                var serverTask = app.RunAsync();

                // Wait for manual shutdown signal
                ShutdownEvent.WaitOne();

                // Stop the server gracefully
                await app.StopAsync();
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to start ASP.NET Core gRPC server: {ex}");
            }
        }

        /// <summary>
        /// Creates an X509Certificate2 with the private key loaded from PEM-formatted data.
        /// Handles platform-specific certificate loading requirements.
        /// </summary>
        /// <param name="certBytes">The certificate bytes</param>
        /// <param name="privateKeyBytes">The private key bytes</param>
        /// <returns>An X509Certificate2 instance with private key loaded</returns>
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
                Logger.Error($"Error loading certificate with private key: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Main entry point for the application.
        /// Configures and starts the gRPC server.
        /// </summary>
        private static void Main()
        {
            // Configure log4net
            ConfigureLogging();

            // Log runtime environment information
            Logger.Info($"Operating System: {RuntimeInformation.OSDescription}");
            Logger.Info($"Architecture: {RuntimeInformation.ProcessArchitecture}");
            Logger.Info($"Runtime: {RuntimeInformation.FrameworkDescription}");

            // Get configuration from environment
            var port = Connection.GetGrcServerPort();
            var tlsEnabled = Environment.GetEnvironmentVariable("GRPC_HELLO_SECURE");
            var backendServer = Environment.GetEnvironmentVariable("GRPC_HELLO_BACKEND");

            // Create service implementation
            var landingServiceImpl = new LandingServiceImpl();

            // Configure backend client if needed
            if (!string.IsNullOrEmpty(backendServer))
            {
                Logger.Info($"Configuring backend connection to: {backendServer}");
                var channel = Connection.GetChannel();
                landingServiceImpl.SetProtoClient(new LandingService.LandingServiceClient(channel));
            }

            // Determine if TLS should be used
            bool useTls = tlsEnabled == "Y";
            Logger.Info($"Starting {(useTls ? "secure" : "insecure")} gRPC server on port {port} [version: {Utils.GetVersion()}]");

            try
            {
                // Start ASP.NET Core gRPC server
                RunGrpcServerAsync(int.Parse(port), useTls, landingServiceImpl).Wait();
            }
            catch (Exception ex)
            {
                Logger.Error($"Server startup failed: {ex}");
                Environment.Exit(1);
            }
        }

        /// <summary>
        /// Configures log4net logging framework.
        /// </summary>
        private static void ConfigureLogging()
        {
            var logRepository = LogManager.GetRepository(Assembly.GetEntryAssembly() ?? throw new InvalidOperationException());
            XmlConfigurator.Configure(logRepository, new FileInfo("log4net.config"));
        }
    }
}