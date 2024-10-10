import ArgumentParser
import GRPC
import HelloCommon
import Logging
import NIOCore
import NIOPosix

import struct Foundation.Data
import struct Foundation.URL

@main
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
struct HelloServer: AsyncParsableCommand {
    func run() async throws {
        let logger = Logger(label: "HelloServer")
        let group: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        do {
            let provider = HelloServiceProvider()
            let conn: Connection = HelloConn()

            // Start the server and print its address once it has started.
            let server = try await Server.insecure(group: group)
                .withServiceProviders([provider])
                .bind(host: "0.0.0.0", port: conn.port)
                .get()

            logger.info("server started on port \(server.channel.localAddress!.port!)")

            // Keep the server running
            try await server.onClose.get()
        } catch {
            logger.error("Server failed with error: \(error)")
        }

        // Shutdown the event loop group gracefully
        group.shutdownGracefully { error in
            if let error = error {
                logger.error("Failed to shutdown event loop group: \(error)")
            }
        }
    }
}
