#if compiler(>=5.6)
import ArgumentParser
import struct Foundation.Data
import struct Foundation.URL
import GRPC
import HelloCommon
import Logging
import NIOCore
import NIOPosix

@main
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct RouteGuide: AsyncParsableCommand {
    func run() async throws {
        let logger = Logger(label: "HelloServer")

        // Create an event loop group for the server to run on.
        let group: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer {
            try! group.syncShutdownGracefully()
        }

        // Create a provider using the features we read.
        let provider = RouteGuideProvider()
        let conn: Connection = HelloConn()
        // Start the server and print its address once it has started.
        let server = try await Server.insecure(group: group)
                .withServiceProviders([provider])
                .bind(host: "localhost", port: conn.port)
                .get()

        logger.info("server started on port \(server.channel.localAddress!.port!)")

        // Wait on the server's `onClose` future to stop the program from exiting.
        try await server.onClose.get()
    }

    init() {
    }

    init(from _: Decoder) throws {
    }
}
#else
@main
enum RouteGuide {
static func main() {
print("This example requires Swift >= 5.6")
}
}
#endif // compiler(>=5.6)
