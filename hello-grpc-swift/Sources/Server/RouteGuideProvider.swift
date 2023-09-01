import Foundation
import GRPC
import HelloCommon
import Logging
import NIOConcurrencyHelpers
import NIOCore

#if compiler(>=5.6)

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    internal final class RouteGuideProvider: Org_Feuyeux_Grpc_LandingServiceAsyncProvider {
        let logger = Logger(label: "HelloService")

        internal init() {}

        // 1
        internal func talk(
            request: Org_Feuyeux_Grpc_TalkRequest,
            context _: GRPCAsyncServerCallContext
        ) async throws -> Org_Feuyeux_Grpc_TalkResponse {
            .with {
                $0.status = 200
                $0.results = [buildResult(rid: request.data)]
            }
        }

        // 2
        internal func talkOneAnswerMore(
            request: Org_Feuyeux_Grpc_TalkRequest,
            responseStream: GRPCAsyncResponseStreamWriter<Org_Feuyeux_Grpc_TalkResponse>,
            context _: GRPCAsyncServerCallContext
        ) async throws {
            let datas: [String] = request.data.components(separatedBy: ",")
            for d in datas {
                try await responseStream.send(.with {
                    $0.status = 200
                    $0.results = [buildResult(rid: d)]
                })
            }
        }

        // 3
        internal func talkMoreAnswerOne(
            requestStream requests: GRPCAsyncRequestStream<Org_Feuyeux_Grpc_TalkRequest>,
            context _: GRPCAsyncServerCallContext
        ) async throws -> Org_Feuyeux_Grpc_TalkResponse {
            var results: [Org_Feuyeux_Grpc_TalkResult] = []
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
            requestStream: GRPCAsyncRequestStream<Org_Feuyeux_Grpc_TalkRequest>,
            responseStream: GRPCAsyncResponseStreamWriter<Org_Feuyeux_Grpc_TalkResponse>,
            context _: GRPCAsyncServerCallContext
        ) async throws {
            for try await request in requestStream {
                logger.info("received: \(request)")
                let result = buildResult(rid: request.data)
                // var results : [Org_Feuyeux_Grpc_TalkResult]=[]
                // results.append(result)
                try await responseStream.send(.with {
                    $0.status = 200
                    $0.results = [result] // results
                })
            }
        }

        func buildResult(rid: String) -> Org_Feuyeux_Grpc_TalkResult {
            let index = Int(rid) ?? 0
            var kv: [String: String] = [:]
            kv["id"] = ""
            kv["idx"] = rid
            let hello: String = Utils.helloList[index]
            kv["data"] = hello + "," + Utils.ansMap[hello]!
            kv["meta"] = "SWIFT"
            var result = Org_Feuyeux_Grpc_TalkResult()
            let now = Date()
            let timeInterval: TimeInterval = now.timeIntervalSince1970
            result.id = Int64(timeInterval)
            result.type = .ok
            result.kv = kv
            return result
        }
    }
#endif // compiler(>=5.6)
