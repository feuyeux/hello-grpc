import * as grpc from '@grpc/grpc-js'
import {sendUnaryData} from '@grpc/grpc-js/build/src/server-call'
import {ILandingServiceServer, LandingServiceService} from "./common/landing_grpc_pb"
import {ResultType, TalkRequest, TalkResponse, TalkResult} from "./common/landing_pb"
import {v4 as uuidv4} from "uuid"
import {ans, hellos} from "./common/utils"
import {logger, port} from "./common/conn"


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
        let response = new TalkResponse()
        response.setStatus(200)
        const talkResult = buildResult(data)
        let talkResults = [talkResult]
        response.setResultsList(talkResults)
        callback(null, response)
    }

    talkMoreAnswerOne(call: grpc.ServerReadableStream<TalkRequest, TalkResponse>, callback: sendUnaryData<TalkResponse>): void {
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