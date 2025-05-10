import ArgumentParser
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import HelloCommon
import Logging

struct HelloService: Hello_LandingService.SimpleServiceProtocol {
    let logger = Logger(label: "HelloService")
    var backendClient: Hello_LandingService.ClientProtocol?

    // Unary RPC implementation
    func talk(
        request: Hello_TalkRequest,
        context _: GRPCCore.ServerContext
    ) async throws -> Hello_TalkResponse {
        logger.info("[\(request.data)] talk request: data=\(request.data), meta=\(request.meta)")

        if let backendClient {
            // Forward request to backend service
            // Create empty metadata since we can't access the client's headers directly
            let startTime = Date()
            logger.info("[\(request.data)] 开始调用后端服务: \(startTime)")
            let response = try await backendClient.talk(request, metadata: [:])
            let endTime = Date()
            let elapsedTime = endTime.timeIntervalSince(startTime)
            logger.info("[\(request.data)] 后端服务调用完成: \(endTime), 耗时: \(elapsedTime)秒")
            return response
        }

        return .with {
            $0.status = 200
            $0.results = [buildResult(rid: request.data)]
        }
    }

    // Server Streaming RPC implementation
    func talkOneAnswerMore(
        request: Hello_TalkRequest,
        response: GRPCCore.RPCWriter<Hello_TalkResponse>,
        context _: GRPCCore.ServerContext
    ) async throws {
        let requestId = UUID().uuidString
        logger.info("[\(requestId)] talkOneAnswerMore request: data=\(request.data), meta=\(request.meta)")

        if let backendClient {
            // Forward request to backend service
            // Create empty metadata since we can't access the client's headers directly
            let startTime = Date()
            logger.info("[\(requestId)] 开始调用后端服务 talkOneAnswerMore: \(startTime)")
            let _ = try await backendClient.talkOneAnswerMore(request, metadata: [:]) { streamResponse in
                logger.info("[\(requestId)] 开始处理 talkOneAnswerMore 流响应")
                for try await responseMessage in streamResponse.messages {
                    try await response.write(responseMessage)
                    logger.info("[\(requestId)] 已写入一条 talkOneAnswerMore 响应")
                }
                let endTime = Date()
                let elapsedTime = endTime.timeIntervalSince(startTime)
                logger.info("[\(requestId)] talkOneAnswerMore 流处理完成: 耗时: \(elapsedTime)秒")
            }
            logger.info("[\(requestId)] talkOneAnswerMore 请求已发送至后端")
            return
        }

        let datas: [String] = request.data.components(separatedBy: ",")
        for d in datas {
            try await response.write(
                .with {
                    $0.status = 200
                    $0.results = [buildResult(rid: d)]
                }
            )
            logger.info("[\(requestId)] talkOneAnswerMore sent response for data=\(d)")
        }
    }

    // Client Streaming RPC implementation
    func talkMoreAnswerOne(
        request: GRPCCore.RPCAsyncSequence<Hello_TalkRequest, any Swift.Error>,
        context _: GRPCCore.ServerContext
    ) async throws -> Hello_TalkResponse {
        let requestId = UUID().uuidString
        logger.info("[\(requestId)] 开始处理 talkMoreAnswerOne 请求")

        if let backendClient {
            // Forward request to backend service
            // Create empty metadata since we can't access the client's headers directly
            let startTime = Date()
            logger.info("[\(requestId)] 开始调用后端服务 talkMoreAnswerOne: \(startTime)")
            let response = try await backendClient.talkMoreAnswerOne(metadata: [:]) { writer in
                for try await req in request {
                    logger.info("[\(requestId)] 转发请求到后端: \(req.data)")
                    try await writer.write(req)
                }
                logger.info("[\(requestId)] 所有客户端请求已转发至后端")
            }
            let endTime = Date()
            let elapsedTime = endTime.timeIntervalSince(startTime)
            logger.info("[\(requestId)] talkMoreAnswerOne 请求完成: 耗时: \(elapsedTime)秒")
            return response
        }

        var results: [Hello_TalkResult] = []
        for try await req in request {
            logger.info("[\(requestId)] talkMoreAnswerOne received request: data=\(req.data), meta=\(req.meta)")
            results.append(buildResult(rid: req.data))
        }

        logger.info("[\(requestId)] talkMoreAnswerOne 处理完成, 返回结果")
        return .with {
            $0.status = 200
            $0.results = results
        }
    }

    // Bidirectional Streaming RPC implementation
    func talkBidirectional(
        request: GRPCCore.RPCAsyncSequence<Hello_TalkRequest, any Swift.Error>,
        response: GRPCCore.RPCWriter<Hello_TalkResponse>,
        context _: GRPCCore.ServerContext
    ) async throws {
        let requestId = UUID().uuidString
        logger.info("[\(requestId)] 开始处理 talkBidirectional 请求")

        if let backendClient {
            // Forward request to backend service
            // Create empty metadata since we can't access the client's headers directly
            let startTime = Date()
            logger.info("[\(requestId)] 开始调用后端服务 talkBidirectional: \(startTime)")
            try await backendClient.talkBidirectional(metadata: [:]) { writer in
                Task {
                    logger.info("[\(requestId)] 开始转发请求到后端服务")
                    for try await req in request {
                        logger.info("[\(requestId)] 转发请求到后端: \(req.data)")
                        try await writer.write(req)
                    }
                    logger.info("[\(requestId)] 完成所有客户端请求转发")
                }
            } onResponse: { streamResponse in
                Task {
                    logger.info("[\(requestId)] 开始处理后端服务响应")
                    for try await responseMessage in streamResponse.messages {
                        logger.info("[\(requestId)] 接收到后端响应")
                        try await response.write(responseMessage)
                        logger.info("[\(requestId)] 已将响应写回客户端")
                    }
                    let endTime = Date()
                    let elapsedTime = endTime.timeIntervalSince(startTime)
                    logger.info("[\(requestId)] talkBidirectional 请求完成: 耗时: \(elapsedTime)秒")
                }
                return ()
            }
            logger.info("[\(requestId)] 已发送 talkBidirectional 请求到后端")
            return
        }

        for try await req in request {
            logger.info("[\(requestId)] talkBidirectional received: data=\(req.data), meta=\(req.meta)")
            let result = buildResult(rid: req.data)
            try await response.write(
                .with {
                    $0.status = 200
                    $0.results = [result]
                }
            )
            logger.info("[\(requestId)] talkBidirectional sent response for data=\(req.data)")
        }
    }

    // Helper method to build a result object based on the request index
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
