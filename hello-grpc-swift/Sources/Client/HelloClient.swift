import ArgumentParser
import Foundation
import GRPC
import HelloCommon
import Logging
import NIOCore
import NIOPosix

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
struct HelloExample {
    let logger = Logger(label: "HelloClient")

    private let client: Hello_LandingServiceAsyncClient

    init(client: Hello_LandingServiceAsyncClient) {
        self.client = client
    }

    func run() async {
        await talk()
        await talkOneAnswerMore()
        await talkMoreAnswerOne()
        await talkBidirectional()
    }
}

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
extension HelloExample {
    private func talk() async {
        logger.info("\n→ talk:")
        let request: Hello_TalkRequest = .with {
            $0.data = "0"
            $0.meta = "SWIFT"
        }
        let callOptions = CallOptions(
            customMetadata: [
                "k1": "v1"
            ],
            timeLimit: .deadline(.now() + .seconds(1))
        )
        do {
            let response = try await client.talk(request, callOptions: callOptions)
            logger.info("Talk Response \(response.status) \(response.results)")
        } catch {
            logger.info("RPC failed: \(error)")
        }
    }

    private func talkOneAnswerMore() async {
        logger.info("\n→ talkOneAnswerMore:")
        let request: Hello_TalkRequest = .with {
            $0.data = "0,1,2"
            $0.meta = "SWIFT"
        }

        do {
            var resultCount = 1
            let callOptions = CallOptions(
                customMetadata: [
                    "k1": "v1"
                ],
                timeLimit: .deadline(.now() + .seconds(1))
            )
            for try await response in client.talkOneAnswerMore(
                request, callOptions: callOptions)
            {
                logger.info(
                    "TalkOneAnswerMore Response[\(resultCount)] \(response.status) \(response.results)"
                )
                resultCount += 1
            }
        } catch {
            logger.info("RPC failed: \(error)")
        }
    }

    private func talkMoreAnswerOne() async {
        logger.info("\n→ talkMoreAnswerOne")
        let rid = Int.random(in: 0..<6)
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
        let callOptions = CallOptions(
            customMetadata: [
                "k1": "v1"
            ],
            timeLimit: .deadline(.now() + .seconds(2))
        )
        let streamingCall = client.makeTalkMoreAnswerOneCall(callOptions: callOptions)
        do {
            for request in requests {
                try await streamingCall.requestStream.send(request)

                // Sleep for 0.2s ... 1.0s before sending the next point.
                try await Task.sleep(nanoseconds: UInt64.random(in: UInt64(2e8)...UInt64(1e9)))
            }

            streamingCall.requestStream.finish()
            let response = try await streamingCall.response
            logger.info("TalkMoreAnswerOne Response \(response.status) \(response.results)")
        } catch {
            logger.info("TalkMoreAnswerOne Failed: \(error)")
        }
    }

    private func talkBidirectional() async {
        logger.info("\n→ talkBidirectional")
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
        let callOptions = CallOptions(
            customMetadata: [
                "k1": "v1"
            ],
            timeLimit: .deadline(.now() + .seconds(3))
        )
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                let streamingCall = client.makeTalkBidirectionalCall(callOptions: callOptions)

                // Add a task to send each message adding a small sleep between each.
                group.addTask {
                    for request in requests {
                        try await streamingCall.requestStream.send(request)
                        // Sleep for 0.2s ... 1.0s before sending the next note.
                        try await Task.sleep(
                            nanoseconds: UInt64.random(in: UInt64(2e8)...UInt64(1e9)))
                    }
                    streamingCall.requestStream.finish()
                }

                // Add a task to logger.info each message received on the response stream.
                group.addTask {
                    do {
                        for try await response in streamingCall.responseStream {
                            logger.info(
                                "TalkBidirectional Response \(response.status) \(response.results)"
                            )
                        }
                    } catch {
                        logger.info("TalkBidirectional Failed: \(error)")
                    }
                }

                try await group.waitForAll()
            }
        } catch {
            logger.info("TalkBidirectional Failed: \(error)")
        }
    }
}

@main
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
struct HelloClient: AsyncParsableCommand {
    func run() async throws {
        let conn = HelloConn()
        let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
        defer {
            Task {
                try await group.shutdownGracefully()
            }
        }

        let connectTo = ProcessInfo.processInfo.environment["GRPC_SERVER"] ?? "localhost"
        let channel = try GRPCChannelPool.with(
            target: .host(connectTo, port: conn.port),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )
        defer {
            Task {
                try await channel.close().get()
            }
        }
        let client = Hello_LandingServiceAsyncClient(channel: channel)
        let example = HelloExample(client: client)
        await example.run()
    }
}
