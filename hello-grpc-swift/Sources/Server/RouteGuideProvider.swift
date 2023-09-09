import Foundation
import GRPC
import HelloCommon
import Logging
import NIOConcurrencyHelpers
import NIOCore

#if compiler(>=5.6)

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    final class RouteGuideProvider: Hello_LandingServiceAsyncProvider {
        let logger = Logger(label: "HelloService")

        init() {}

        // 1
        func talk(
            request: Hello_TalkRequest,
            context: GRPCAsyncServerCallContext
        ) async throws -> Hello_TalkResponse {
            let headers = context.request.headers
            logger.info("talk headers: \(headers)")

            return .with {
                $0.status = 200
                $0.results = [buildResult(rid: request.data)]
            }
        }

        // 2
        func talkOneAnswerMore(
            request: Hello_TalkRequest,
            responseStream: GRPCAsyncResponseStreamWriter<Hello_TalkResponse>,
            context: GRPCAsyncServerCallContext
        ) async throws {
            let headers = context.request.headers
            logger.info("talkOneAnswerMore headers: \(headers)")

            let datas: [String] = request.data.components(separatedBy: ",")
            for d in datas {
                try await responseStream.send(.with {
                    $0.status = 200
                    $0.results = [buildResult(rid: d)]
                })
            }
        }

        // 3
        func talkMoreAnswerOne(
            requestStream requests: GRPCAsyncRequestStream<Hello_TalkRequest>,
            context: GRPCAsyncServerCallContext
        ) async throws -> Hello_TalkResponse {
            let headers = context.request.headers
            logger.info("talkMoreAnswerOne headers: \(headers)")

            var results: [Hello_TalkResult] = []
            for try await request in requests {
                results.append(buildResult(rid: request.data))
            }
            return .with {
                $0.status = 200
                $0.results = results
            }
        }

        // 4
        func talkBidirectional(
            requestStream: GRPCAsyncRequestStream<Hello_TalkRequest>,
            responseStream: GRPCAsyncResponseStreamWriter<Hello_TalkResponse>,
            context: GRPCAsyncServerCallContext
        ) async throws {
            let headers = context.request.headers
            logger.info("talkBidirectional headers: \(headers)")

            for try await request in requestStream {
                logger.info("received: \(request)")
                let result = buildResult(rid: request.data)
                // var results : [Hello_TalkResult]=[]
                // results.append(result)
                try await responseStream.send(.with {
                    $0.status = 200
                    $0.results = [result] // results
                })
            }
        }

        func buildResult(rid: String) -> Hello_TalkResult {
            let index = Int(rid) ?? 0
            var kv: [String: String] = [:]
            kv["id"] = ""
            kv["idx"] = rid
            let hello: String = Utils.helloList[index]
            kv["data"] = hello + "," + Utils.ansMap[hello]!
            kv["meta"] = "SWIFT"
            var result = Hello_TalkResult()
            let now = Date()
            let timeInterval: TimeInterval = now.timeIntervalSince1970
            result.id = Int64(timeInterval)
            result.type = .ok
            result.kv = kv
            return result
        }
    }
#endif // compiler(>=5.6)
