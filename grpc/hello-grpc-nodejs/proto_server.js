const grpc = require('@grpc/grpc-js')
let uuid = require('uuid')
let messages = require('./common/landing_pb')
let services = require('./common/landing_grpc_pb')
let conn = require('./common/connection')
//let ref = require('grpc-node-server-reflection')

const fs = require('fs')

let hellos = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"]

let tracingKeys = [
    "x-request-id",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-ot-span-context"
]

const logger = conn.logger
let next
const cert = "/var/hello_grpc/server_certs/cert.pem"
const certKey = "/var/hello_grpc/server_certs/private.key"
const certChain = "/var/hello_grpc/server_certs/full_chain.pem"
const rootCert = "/var/hello_grpc/server_certs/myssl_root.cer"


/**
 * Starts an RPC server that receives requests for the Greeter service at the
 * sample server port
 */
function main() {
    if (hasBackend()) {
        next = conn.getClient()
    }

    let port = process.env.GRPC_SERVER_PORT
    if (typeof port == 'undefined' || port == null) {
        port = "9996"
    }
    let address = "0.0.0.0:" + port

    //const server =ref.default(new grpc.Server())
    let server = new grpc.Server()
    server.addService(services.LandingServiceService, {
        talk: talk,
        talkOneAnswerMore: talkOneAnswerMore,
        talkMoreAnswerOne: talkMoreAnswerOne,
        talkBidirectional: talkBidirectional
    })

    let secure = process.env.GRPC_HELLO_SECURE
    if (typeof secure !== 'undefined' && secure !== null && secure === "Y") {
        let checkClientCertificate = false;
        let rootCertContent = fs.readFileSync(rootCert);
        let certChainContent = fs.readFileSync(certChain);
        let privateKeyContent = fs.readFileSync(certKey);
        let credentials = grpc.ServerCredentials.createSsl(
            rootCertContent,
            [{cert_chain: certChainContent, private_key: privateKeyContent}],
            checkClientCertificate
        )
        server.bindAsync(address, credentials, () => {
            server.start()
            logger.info("Start GRPC TLS Server[%s]", port)
        })
    } else {
        server.bindAsync(address, grpc.ServerCredentials.createInsecure(), () => {
            server.start()
            logger.info("Start GRPC Server[%s]", port)
        })
    }
}

function talk(call, callback) {
    let request = call.request
    logger.info("TALK REQUEST: data=%s,meta=%s", request.getData(), request.getMeta())
    let metadata = propagandaHeaders("Talk", call)
    if (hasNext()) {
        next.talk(request, metadata, function (err, response) {
            callback(null, response)
        })
    } else {
        let response = new messages.TalkResponse()
        response.setStatus(200)
        const talkResult = buildResult(request.getData())
        let talkResults = [talkResult]
        response.setResultsList(talkResults)
        callback(null, response)
    }
}

function talkOneAnswerMore(call) {
    let request = call.request
    logger.info("TalkOneAnswerMore REQUEST: data=%s,meta=%s", request.getData(), request.getMeta())
    let metadata = propagandaHeaders("TalkOneAnswerMore", call)
    if (hasNext()) {
        let nextCall = next.talkOneAnswerMore(request, metadata)
        nextCall.on('data', function (response) {
            call.write(response)
        })
        nextCall.on('end', function () {
            call.end()
        })
    } else {
        let datas = request.getData().split(",")
        for (const data in datas) {
            let response = new messages.TalkResponse()
            response.setStatus(200)
            const talkResult = buildResult(data)
            let talkResults = [talkResult]
            response.setResultsList(talkResults)
            logger.info("TalkOneAnswerMore:%s", response)
            call.write(response)
        }
        call.end()
    }
}

function talkMoreAnswerOne(call, callback) {
    let metadata = propagandaHeaders("TalkMoreAnswerOne", call)
    if (hasNext()) {
        let nextCall = next.talkMoreAnswerOne(metadata, function (err, response) {
            if (err) {
                logger.error(err)
            } else {
                callback(null, response)
            }
        })
        call.on('data', function (request) {
            logger.info("TalkMoreAnswerOne REQUEST: data=%s,meta=%s", request.getData(), request.getMeta())
            nextCall.write(request)
        })
        call.on('end', function () {
            nextCall.end()
        })
        call.on('error', function (e) {
            logger.error(e)
        })
    } else {
        let talkResults = []
        call.on('data', function (request) {
            logger.info("TalkMoreAnswerOne REQUEST: data=%s,meta=%s", request.getData(), request.getMeta())
            talkResults.push(buildResult(request.getData()))
        })
        call.on('end', function () {
            let response = new messages.TalkResponse()
            response.setStatus(200)
            response.setResultsList(talkResults)
            callback(null, response)
        })
        call.on('error', function (e) {
            logger.error(e)
        })
    }
}

function talkBidirectional(call) {
    let metadata = propagandaHeaders("TalkBidirectional", call)
    if (hasNext()) {
        let nextCall = next.talkBidirectional(metadata)
        nextCall.on('data', function (response) {
            call.write(response)
        })
        nextCall.on('end', function () {
            call.end()
        })

        call.on('data', function (request) {
            nextCall.write(request)
        })
        call.on('end', function () {
            nextCall.end()
        })
    } else {
        call.on('data', function (request) {
            logger.info("TalkBidirectional REQUEST: data=%s,meta=%s", request.getData(), request.getMeta())
            let response = new messages.TalkResponse()
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

function hasBackend() {
    let backend = process.env.GRPC_HELLO_BACKEND
    return typeof backend !== 'undefined' && backend !== null
}

function hasNext() {
    return typeof next !== 'undefined' && next !== null;
}

// {"status":200,"results":[{"id":1600402320493411000,"kv":{"data":"Hello","id":"0"}}]}
function buildResult(id) {
    let result = new messages.TalkResult()
    let index = parseInt(id)
    result.setId(Math.round(Date.now() / 1000))
    result.setType(messages.ResultType.OK)
    let kv = result.getKvMap()
    kv.set("id", uuid.v1())
    kv.set("idx", id)
    kv.set("data", hellos[index])
    kv.set("meta", "NODEJS")
    return result
}

function propagandaHeaders(methodName, call) {
    let headers = call.metadata.getMap()
    const metadata = new grpc.Metadata()
    for (let key in headers) {
        logger.info("%s HEADER: %s:%s", methodName, key, headers[key])
        if (key in tracingKeys) {
            metadata.add(key, headers[key])
        }
    }
    return metadata
}

main()