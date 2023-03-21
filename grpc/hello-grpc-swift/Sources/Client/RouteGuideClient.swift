#if compiler(>=5.6)
import ArgumentParser
import Foundation
import GRPC
import NIOCore
import NIOPosix
import HelloCommon

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
internal struct HelloExample {
    private let client: Org_Feuyeux_Grpc_LandingServiceAsyncClient

    init(client: Org_Feuyeux_Grpc_LandingServiceAsyncClient) {
        self.client = client
    }

    func run() async {
        await talk()

    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension HelloExample {
    private func talk() async {
        print("\n→ talk:")
        let request: Org_Feuyeux_Grpc_TalkRequest = .with {
            $0.data = "0"
            $0.meta = "SWIFT"
        }
        do {
            let response = try await client.talk(request)
            print("response \(response.status) \(response.results)")
        } catch {
            print("RPC failed: \(error)")
        }
    }

    private func talkOneAnswerMore() async {
        print("\n→ talkOneAnswerMore:")
        let request: Org_Feuyeux_Grpc_TalkRequest = .with {
            $0.data = "0,1,2"
            $0.meta = "SWIFT"
        }
        do {
            var resultCount = 1
            for try await response in self.client.talkOneAnswerMore(request) {
                print("response[\(resultCount)] \(response.status) \(response.results)")
                resultCount += 1
            }
        } catch {
            print("RPC failed: \(error)")
        }
    }

    private func talkMoreAnswerOne() async {
        print("\n→ talkMoreAnswerOne")

        let requests: [Org_Feuyeux_Grpc_TalkRequest] = [
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
            }
        ]

        let streamingCall = client.makeTalkMoreAnswerOneCall()
        do {
            for request in requests {
                try await streamingCall.requestStream.send(request)

                // Sleep for 0.2s ... 1.0s before sending the next point.
                try await Task.sleep(nanoseconds: UInt64.random(in: UInt64(2e8)...UInt64(1e9)))
            }

            streamingCall.requestStream.finish()
            let response = try await streamingCall.response
            print("response \(response.status) \(response.results)")
        } catch {
            print("talkMoreAnswerOne Failed: \(error)")
        }
    }

    private func talkBidirectional() async {
        print("\n→ talkBidirectional")

        let requests: [Org_Feuyeux_Grpc_TalkRequest] = [
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
            }
        ]

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                let streamingCall = client.makeTalkBidirectionalCall()

                // Add a task to send each message adding a small sleep between each.
                group.addTask {
                    for request in requests {
                        try await streamingCall.requestStream.send(request)
                        // Sleep for 0.2s ... 1.0s before sending the next note.
                        try await Task.sleep(nanoseconds: UInt64.random(in: UInt64(2e8)...UInt64(1e9)))
                    }
                    streamingCall.requestStream.finish()
                }

                // Add a task to print each message received on the response stream.
                group.addTask {
                    do {
                        for try await response in streamingCall.responseStream {
                            print("response \(response.status) \(response.results)")
                        }
                    } catch {
                        print("talkBidirectional Failed: \(error)")
                    }
                }

                try await group.waitForAll()
            }
        } catch {
            print("talkBidirectional Failed: \(error)")
        }
    }
}

@main
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct RouteGuide: AsyncParsableCommand {
    @Option(help: "The port to connect to")
    var port: Int = 1234

    func run() async throws {
        let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
        defer {
            try? group.syncShutdownGracefully()
        }

        let channel = try GRPCChannelPool.with(
                target: .host("localhost", port: self.port),
                transportSecurity: .plaintext,
                eventLoopGroup: group
        )
        defer {
            try? channel.close().wait()
        }

        let client = Org_Feuyeux_Grpc_LandingServiceAsyncClient(channel: channel)
        let example = HelloExample(client: client)
        await example.run()
    }
}

extension Routeguide_Point: CustomStringConvertible {
    public var description: String {
        return "(\(self.latitude), \(self.longitude))"
    }
}

extension Routeguide_Feature: CustomStringConvertible {
    public var description: String {
        return "\(self.name) at \(self.location)"
    }
}
#else
@main
enum NotAvailable {
static func main() {
print("This example requires Swift >= 5.6")
}
}
#endif // compiler(>=5.6)
