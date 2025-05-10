import ArgumentParser
@preconcurrency import Dispatch
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import HelloCommon
import Logging
import NIOCore
import NIOPosix
import NIOSSL

/// Main server command for the gRPC Hello service.
/// Supports both secure (TLS) and insecure connections.
struct HelloServer: AsyncParsableCommand {
    /// Command-line options for server configuration
    struct Options {
        /// Determines whether the server should run in proxy mode
        var isProxyMode: Bool {
            ProcessInfo.processInfo.environment["GRPC_HELLO_PROXY"] == "Y"
        }

        /// Determines whether TLS is enabled from environment variable
        var useTLS: Bool {
            ProcessInfo.processInfo.environment["GRPC_HELLO_SECURE"] == "Y"
        }

        /// Gets the certificate base path from environment or default location
        var certBasePath: String {
            if let path = ProcessInfo.processInfo.environment["CERT_BASE_PATH"] {
                return path
            }

            #if os(macOS)
                return "/var/hello_grpc/server_certs"
            #elseif os(Windows)
                return "D:\\garden\\var\\hello_grpc\\server_certs"
            #else
                return "/var/hello_grpc/server_certs"
            #endif
        }
    }

    /// The entry point for the server command
    func run() async throws {
        let logger = Logger(label: "HelloServer")
        logger.info("Starting gRPC server...")

        let options = Options()
        let conn: Connection = HelloConn()

        do {
            // Set up backend connection if in proxy mode
            var backendClient: Hello_LandingService.ClientProtocol? = nil

            if options.isProxyMode || conn.hasBackend {
                logger.info("Initializing in proxy mode")
                let backendHost = conn.backendHost ?? "127.0.0.1"
                let backendPort = conn.backendPort ?? 9996

                logger.info("Connecting to backend at \(backendHost):\(backendPort)")

                let backendTransport: HTTP2ClientTransport.Posix

                if options.useTLS {
                    // Create secure transport for backend connection
                    logger.info("Using TLS for backend connection")
                    let certBasePath = options.certBasePath
                    let rootCertPath = "\(certBasePath)/full_chain.pem"

                    backendTransport = try HTTP2ClientTransport.Posix(
                        target: .ipv4(host: backendHost, port: backendPort),
                        transportSecurity: .tls(
                            .init(
                                certificateChain: [],
                                privateKey: nil,
                                serverCertificateVerification: .noVerification,
                                trustRoots: .certificates([.file(path: rootCertPath, format: .pem)])
                            )
                        )
                    )
                } else {
                    // Create plaintext transport for backend connection
                    logger.info("Using plaintext for backend connection")
                    backendTransport = try HTTP2ClientTransport.Posix(
                        target: .ipv4(host: backendHost, port: backendPort),
                        transportSecurity: .plaintext
                    )
                }

                // Create the backend client
                let client = GRPCClient(transport: backendTransport)
                backendClient = Hello_LandingService.Client(wrapping: client)
                logger.info("Backend connection established")
            }

            // Create HelloService with or without the backend client
            let service = HelloService(backendClient: backendClient)
            logger.info("Service initialized \(backendClient != nil ? "with" : "without") backend")

            let transport: HTTP2ServerTransport.Posix

            // Configure TLS if enabled
            if options.useTLS {
                logger.info("TLS is enabled, configuring secure transport")
                guard let host = conn.host, !host.isEmpty else {
                    logger.error("GRPC_SERVER 环境变量未设置，必须指定 host 以支持多实例启动")
                    throw RuntimeError("GRPC_SERVER 环境变量未设置，必须指定 host")
                }
                transport = createSecureTransport(
                    options: options,
                    host: host,
                    port: conn.port ?? 9996,
                    logger: logger
                )
            } else {
                logger.info("Using plaintext transport")
                guard let host = conn.host, !host.isEmpty else {
                    logger.error("GRPC_SERVER 环境变量未设置，必须指定 host 以支持多实例启动")
                    throw RuntimeError("GRPC_SERVER 环境变量未设置，必须指定 host")
                }
                transport = HTTP2ServerTransport.Posix(
                    address: .ipv4(host: host, port: conn.port ?? 9996),
                    transportSecurity: .plaintext
                )
            }

            // Create and start the server
            let server = GRPCServer(transport: transport, services: [service])

            // Handle signals for graceful shutdown
            let signalSource = makeSignalSource()

            try await withThrowingDiscardingTaskGroup { group in
                // Start the server
                group.addTask { try await server.serve() }

                // Wait for the server to start and log the address
                let address = try await transport.listeningAddress
                logger.info("Server started on port \(address)")
                logger.info("Version: \(Utils.getVersion())")

                // Handle graceful shutdown with an event-driven approach
                // This task will complete when a signal is received
                try await withTaskCancellationHandler {
                    for await _ in signalSource {
                        logger.info("Received shutdown signal, stopping server...")
                        throw CancellationError()
                    }
                } onCancel: {
                    logger.info("Server shutdown initiated")
                }
            }
        } catch is CancellationError {
            logger.info("Server shut down gracefully")
        } catch {
            logger.error("Server failed with error: \(error)")
            throw error
        }
    }

    /// Creates a secure transport with TLS configuration
    private func createSecureTransport(
        options: Options,
        host: String,
        port: Int,
        logger: Logger
    ) -> HTTP2ServerTransport.Posix {
        let keyPath = "\(options.certBasePath)/private.key"
        let chainPath = "\(options.certBasePath)/full_chain.pem"

        logger.info("Using certificates from: \(options.certBasePath)")

        // Create TLS certificate chain and private key
        return HTTP2ServerTransport.Posix(
            address: .ipv4(host: host, port: port),
            transportSecurity: .tls(
                certificateChain: [.file(path: chainPath, format: .pem)],
                privateKey: .file(path: keyPath, format: .pem)
            )
        )
    }

    /// Creates a signal source for graceful shutdown
    private func makeSignalSource() -> AsyncStream<Void> {
        let signalQueue = DispatchQueue(label: "signal-queue")
        let signalSource = AsyncStream<Void> { continuation in
            let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue)
            let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: signalQueue)

            sigintSource.setEventHandler {
                continuation.yield()
                continuation.finish()
            }

            sigtermSource.setEventHandler {
                continuation.yield()
                continuation.finish()
            }

            sigintSource.resume()
            sigtermSource.resume()

            signal(SIGINT, SIG_IGN)
            signal(SIGTERM, SIG_IGN)

            continuation.onTermination = { _ in
                sigintSource.cancel()
                sigtermSource.cancel()
                signal(SIGINT, SIG_DFL)
                signal(SIGTERM, SIG_DFL)
            }
        }

        return signalSource
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

@main
extension HelloServer {}
