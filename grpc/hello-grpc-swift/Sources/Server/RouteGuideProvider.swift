import Foundation
import GRPC
import NIOConcurrencyHelpers
import NIOCore
import Logging
import HelloCommon

#if compiler(>=5.6)

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
internal final class RouteGuideProvider: Org_Feuyeux_Grpc_LandingServiceAsyncProvider {
    let logger = Logger(label: "HelloService")

    let helloList: [String] = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"]
    let ansMap: [String: String] = ["你好": "非常感谢",
                                    "Hello": "Thank you very much",
                                    "Bonjour": "Merci beaucoup",
                                    "Hola": "Muchas Gracias",
                                    "こんにちは": "どうも ありがとう ございます",
                                    "Ciao": "Mille Grazie",
                                    "안녕하세요": "대단히 감사합니다"]
    internal init() {

    }

    // 1
    internal func talk(
            request: Org_Feuyeux_Grpc_TalkRequest,
            context: GRPCAsyncServerCallContext
    ) async throws -> Org_Feuyeux_Grpc_TalkResponse {
        .with {
            $0.status = 200
            $0.results = []
        }
    }

    // 2
    internal func talkOneAnswerMore(
            request: Org_Feuyeux_Grpc_TalkRequest,
            responseStream: GRPCAsyncResponseStreamWriter<Org_Feuyeux_Grpc_TalkResponse>,
            context: GRPCAsyncServerCallContext
    ) async throws {
        let datas = request.data.split(separator: ",")
        for d in datas {
            print("received: \(d)")
            try await responseStream.send(.with {
                $0.status = 200
                $0.results = []
            })
        }
    }

    // 3
    internal func talkMoreAnswerOne(
            requestStream requests: GRPCAsyncRequestStream<Org_Feuyeux_Grpc_TalkRequest>,
            context: GRPCAsyncServerCallContext
    ) async throws -> Org_Feuyeux_Grpc_TalkResponse {
        let results: [Org_Feuyeux_Grpc_TalkResult] = []
        for try await request in requests {
            logger.info("received: \(request)")
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
            context: GRPCAsyncServerCallContext
    ) async throws {
        for try await request in requestStream {
            try await responseStream.send(.with {
                $0.status = 200
                $0.results = []
            })
        }
    }
}
#endif // compiler(>=5.6)
