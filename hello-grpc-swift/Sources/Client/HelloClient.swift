// Swift gRPC Client
import ArgumentParser
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import HelloCommon
import Logging
import NIOCore
import NIOSSL

struct HelloClient: AsyncParsableCommand {
    func run() async throws {
        let logger = Logger(label: "HelloClient")
        let conn = HelloConn()
        let connectTo = conn.host ?? "127.0.0.1"
        let useTLS = ProcessInfo.processInfo.environment["GRPC_HELLO_SECURE"] == "Y"

        logger.info("Connecting to \(connectTo):\(conn.port ?? 9996) (secure: \(useTLS))")

        do {
            // Configure transport based on TLS flag
            let transport: HTTP2ClientTransport.Posix

            if useTLS {
                logger.info("Using TLS with transport security")

                // Get certificate paths
                let certBasePath = getCertBasePath()
                let rootCertPath = "\(certBasePath)/full_chain.pem"

                logger.info("Using certificates from: \(certBasePath)")

                do {
                    if FileManager.default.fileExists(atPath: rootCertPath) {
                        logger.info("Loading root certificate: \(rootCertPath)")

                        // Create TLS configuration with root certificate for verification
                        transport = try HTTP2ClientTransport.Posix(
                            target: .ipv4(host: connectTo, port: conn.port ?? 9996),
                            transportSecurity: .tls(
                                .init(
                                    certificateChain: [],
                                    privateKey: nil,
                                    // serverCertificateVerification: .fullVerification,
                                    serverCertificateVerification: .noVerification,
                                    trustRoots: .certificates([.file(path: rootCertPath, format: .pem)])
                                )
                            )
                        )
                    } else {
                        logger.warning("Root certificate not found, using default configuration")

                        // Use a minimal TLS configuration when certificates are not available
                        transport = try HTTP2ClientTransport.Posix(
                            target: .ipv4(host: connectTo, port: conn.port ?? 9996),
                            transportSecurity: .tls(
                                .init(
                                    certificateChain: [],
                                    privateKey: nil,
                                    serverCertificateVerification: .fullVerification,
                                    trustRoots: .certificates([])
                                )
                            )
                        )
                    }
                    logger.info("TLS configuration successful")
                } catch {
                    logger.error("Failed to configure TLS: \(error), falling back to plaintext")
                    transport = try HTTP2ClientTransport.Posix(
                        target: .ipv4(host: String(connectTo), port: conn.port ?? 9996),
                        transportSecurity: .plaintext
                    )
                }
            } else {
                // Use plaintext for insecure connections
                transport = try HTTP2ClientTransport.Posix(
                    target: .ipv4(host: String(connectTo), port: conn.port ?? 9996),
                    transportSecurity: .plaintext
                )

                logger.info("Using plaintext connection")
            }

            logger.info("Transport created successfully")

            try await withGRPCClient(transport: transport) { client in
                let serviceClient: Hello_LandingService.Client<HTTP2ClientTransport.Posix> =
                    Hello_LandingService.Client(wrapping: client)
                await Self.runAllTests(client: serviceClient, logger: logger)
            }
        } catch {
            logger.error("Failed to create transport: \(error)")
            throw error
        }
    }

    // Get the certificate base path from environment or default location
    private func getCertBasePath() -> String {
        if let path = ProcessInfo.processInfo.environment["CERT_BASE_PATH"] {
            return path
        }

        #if os(macOS)
            return "/var/hello_grpc/client_certs"
        #elseif os(Windows)
            return "D:\\garden\\var\\hello_grpc\\client_certs"
        #else
            return "/var/hello_grpc/client_certs"
        #endif
    }

    // Run all the test methods
    private static func runAllTests(client: Hello_LandingService.ClientProtocol, logger: Logger) async {
        await talk(client: client, logger: logger)

        do {
            try await talkOneAnswerMore(client: client, logger: logger)
        } catch {
            logger.error("talkOneAnswerMore failed: \(error)")
        }

        do {
            try await talkMoreAnswerOne(client: client, logger: logger)
        } catch {
            logger.error("talkMoreAnswerOne failed: \(error)")
        }

        do {
            try await talkBidirectional(client: client, logger: logger)
        } catch {
            logger.error("talkBidirectional failed: \(error)")
        }
    }

    // Unary RPC: Client sends a single request and server responds with a single message
    static func talk(client: Hello_LandingService.ClientProtocol, logger: Logger) async {
        logger.info("→ talk:")
        let request: Hello_TalkRequest = .with {
            $0.data = "0"
            $0.meta = "SWIFT"
        }

        let metadata: Metadata = ["k1": "v1"]

        do {
            let response = try await client.talk(request, metadata: metadata)
            logger.info("Talk Response \(response.status) \(formatResponse(response))")
        } catch {
            logger.error("RPC failed: \(error)")
        }
    }

    // Server Streaming RPC: Client sends a single request, server responds with a stream of messages
    static func talkOneAnswerMore(
        client: Hello_LandingService.ClientProtocol,
        logger: Logger
    ) async throws {
        logger.info("→ talkOneAnswerMore:")
        let request: Hello_TalkRequest = .with {
            $0.data = "0,1,2"
            $0.meta = "SWIFT"
        }
        try await client.talkOneAnswerMore(request) { response in
            var resultCount = 1
            for try await resp in response.messages {
                logger.info(
                    "TalkOneAnswerMore Response[\(resultCount)] \(resp.status) \(formatResponse(resp))"
                )
                resultCount += 1
            }
        }
    }

    // Client Streaming RPC: Client sends a stream of messages, server responds with a single message
    static func talkMoreAnswerOne(
        client: Hello_LandingService.ClientProtocol,
        logger: Logger
    ) async throws {
        logger.info("→ talkMoreAnswerOne")
        let rid = Int.random(in: 0 ..< 6)
        let requests: [Hello_TalkRequest] = [
            .with {
                $0.data = String(rid)
                $0.meta = "SWIFT"
            },
            .with {
                $0.data = "1"
                $0.meta = "SWIFT"
            },
            .with {
                $0.data = "2"
                $0.meta = "SWIFT"
            },
        ]

        let response = try await client.talkMoreAnswerOne { writer in
            try await writer.write(contentsOf: requests)
        }
        logger.info("TalkMoreAnswerOne Response \(response.status) \(formatResponse(response))")
    }

    // Bidirectional Streaming RPC: Both client and server send streams of messages to each other
    static func talkBidirectional(
        client: Hello_LandingService.ClientProtocol,
        logger: Logger
    ) async throws {
        logger.info("→ talkBidirectional")
        let requests: [Hello_TalkRequest] = [
            .with {
                $0.data = "0"
                $0.meta = "SWIFT"
            },
            .with {
                $0.data = "1"
                $0.meta = "SWIFT"
            },
            .with {
                $0.data = "2"
                $0.meta = "SWIFT"
            },
        ]

        try await client.talkBidirectional { writer in
            for request in requests {
                try await Task.sleep(
                    nanoseconds: UInt64.random(in: UInt64(2e8) ... UInt64(1e9))
                )
                try await writer.write(request)
            }
        } onResponse: { responses in
            for try await response in responses.messages {
                logger.info("TalkBidirectional Response \(response.status) \(formatResponse(response))")
            }
        }
    }

    // Formats the TalkResponse results into a single-line string for logging
    private static func formatResponse(_ response: Hello_TalkResponse) -> String {
        var parts: [String] = []

        if !response.results.isEmpty {
            for result in response.results {
                var resultParts: [String] = []
                resultParts.append("id: \(result.id)")

                // Add all key-value pairs
                var kvPairs: [String] = []
                for (key, value) in result.kv {
                    kvPairs.append("\(key): \"\(value)\"")
                }

                resultParts.append("kv: {" + kvPairs.joined(separator: ", ") + "}")
                parts.append("{" + resultParts.joined(separator: ", ") + "}")
            }
            return "[" + parts.joined(separator: ", ") + "]"
        } else {
            return "[]"
        }
    }
}

@main
extension HelloClient {}
