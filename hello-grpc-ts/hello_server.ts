import * as grpc from '@grpc/grpc-js'
import { sendUnaryData } from '@grpc/grpc-js/build/src/server-call'
import { ILandingServiceServer, LandingServiceService } from "./common/landing_grpc_pb"
import { ResultType, TalkRequest, TalkResponse, TalkResult } from "./common/landing_pb"
import { v4 as uuidv4 } from "uuid"
import { ans, hellos } from "./common/utils"
import { logger, port } from "./common/conn"

let tracingKeys = [
    "x-request-id",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-ot-span-context"
]

function buildResult(data: string): TalkResult {
    let result = new TalkResult()
    let index = parseInt(data)
    let hello = hellos[index]
    result.setId(Math.round(Date.now() / 1000))
    result.setType(ResultType.OK)
    let kv = result.getKvMap()
    kv.set("id", uuidv4())
    kv.set("idx", data)
    kv.set("data", hello + "," + ans.get(hello))
    kv.set("meta", "TypeScript")
    return result
}

class HelloServer implements ILandingServiceServer {
    [name: string]: grpc.UntypedHandleCall

    talk(call: grpc.ServerUnaryCall<TalkRequest, TalkResponse>, callback: sendUnaryData<TalkResponse>): void {
        const data = call.request.getData()
        const meta = call.request.getMeta()
        logger.info("TALK REQUEST: data=%s,meta=%s", data, meta)
        let headers = call.metadata.getMap()
        let metadata = propagandaHeaders("Talk", headers)
        if (metadata.getMap.length > 0) {
            logger.info("TALK TRACING HEADERS: %s", metadata)
        }
        let response = new TalkResponse()
        response.setStatus(200)
        const talkResult = buildResult(data)
        let talkResults = [talkResult]
        response.setResultsList(talkResults)
        callback(null, response)
    }

    talkMoreAnswerOne(call: grpc.ServerReadableStream<TalkRequest, TalkResponse>, callback: sendUnaryData<TalkResponse>): void {
        let headers = call.metadata.getMap()
        let metadata = propagandaHeaders("TalkMoreAnswerOne", headers)
        if (metadata.getMap.length > 0) {
            logger.info("TalkMoreAnswerOne TRACING HEADERS: %s", metadata)
        }
        let talkResults: TalkResult[] = []
        call.on('data', function (request) {
            logger.info("TalkMoreAnswerOne REQUEST: data=%s,meta=%s", request.getData(), request.getMeta())
            talkResults.push(buildResult(request.getData()))
        })
        call.on('end', function () {
            let response = new TalkResponse()
            response.setStatus(200)
            response.setResultsList(talkResults)
            callback(null, response)
        })
        call.on('error', function (e) {
            logger.error(e)
        })
    }

    talkOneAnswerMore(call: grpc.ServerWritableStream<TalkRequest, TalkResponse>): void {
        let request = call.request
        logger.info("TalkOneAnswerMore REQUEST: data=%s,meta=%s", request.getData(), request.getMeta())
        let headers = call.metadata.getMap()
        let metadata = propagandaHeaders("TalkOneAnswerMore", headers)
        if (metadata.getMap.length > 0) {
            logger.info("TalkOneAnswerMore TRACING HEADERS: %s", metadata)
        }
        let datas = request.getData().split(",")
        for (const data in datas) {
            let response = new TalkResponse()
            response.setStatus(200)
            const talkResult = buildResult(data)
            let talkResults = [talkResult]
            response.setResultsList(talkResults)
            logger.info("TalkOneAnswerMore:%s", response)
            call.write(response)
        }
        call.end()
    }

    talkBidirectional(call: grpc.ServerDuplexStream<TalkRequest, TalkResponse>): void {
        let headers = call.metadata.getMap()
        let metadata = propagandaHeaders("TalkBidirectional", headers)
        if (metadata.getMap.length > 0) {
            logger.info("TalkBidirectional TRACING HEADERS: %s", metadata)
        }
        call.on('data', function (request) {
            logger.info("TalkBidirectional REQUEST: data=%s,meta=%s", request.getData(), request.getMeta())
            let response = new TalkResponse()
            response.setStatus(200)
            let data = request.getData()
            const talkResult = buildResult(data)
            let talkResults = [talkResult]
            response.setResultsList(talkResults)
            logger.info("TalkBidirectional:%s", response)
            call.write(response)
        })
        call.on('end', function () {
            call.end()
        })
    }
}

function propagandaHeaders(methodName: string, headers: { [key: string]: grpc.MetadataValue }) {
    let metadata = new grpc.Metadata()
    for (let key in headers) {
        const value = headers[key]
        logger.info("%s HEADER: %s:%s", methodName, key, value)
        if (key in tracingKeys) {
            metadata.add(key, value)
        }
    }
    return metadata
}

function startServer() {
    const server = new grpc.Server()
    server.addService(LandingServiceService, new HelloServer())

    server.bindAsync(
        "0.0.0.0:" + port,
        grpc.ServerCredentials.createInsecure(),
        (error, port) => {
            if (error) {
                logger.error("Fail to start GRPC Server[%s]", port, error)
            }
            server.start()
            logger.info("Start GRPC Server[%s]", port)
        }
    )
}

startServer()