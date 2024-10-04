import ArgumentParser

import GRPC

import HelloCommon

import Logging

import NIOCore

import NIOPosix

import struct Foundation.Data

import struct Foundation.URL

struct HelloServer: AsyncParsableCommand {
    func run() async throws {
        let logger = Logger(label: "HelloServer")

        // Create an event loop group for the server to run on.
        let group: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer {
            try! group.syncShutdownGracefully()
        }

        // Create a provider using the features we read.
        let provider = HelloServiceProvider()
        let conn: Connection = HelloConn()
        // Start the server and print its address once it has started.
        let server = try await Server.insecure(group: group)
            .withServiceProviders([provider])
            .bind(host: "0.0.0.0", port: conn.port)
            .get()

        logger.info("server started on port \(server.channel.localAddress!.port!)")

        // Wait on the server's `onClose` future to stop the program from exiting.
        try await server.onClose.get()
    }

    init() {}

    init(from _: Decoder) throws {}
}
