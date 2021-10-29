const grpc = require('@grpc/grpc-js')
let uuid = require('uuid')
let messages = require('./common/landing_pb')
let services = require('./common/landing_grpc_pb')
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
//
const {createLogger, format, transports} = require('winston')
const {combine, timestamp, printf} = format
const formatter = printf(({level, message, timestamp}) => {
    return `${timestamp} ${level}: ${message}`
})
const logger = createLogger({
    level: 'info',
    format: combine(
        timestamp(),
        formatter
    ),
    transports: [new transports.Console()],
})
//
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
    let backend = process.env.GRPC_HELLO_BACKEND
    let backPort = process.env.GRPC_HELLO_BACKEND_PORT
    let currentPort = process.env.GRPC_SERVER_PORT
    let secure = process.env.GRPC_HELLO_SECURE

    if (typeof backend !== 'undefined' && backend !== null) {
        let address
        if (typeof backPort !== 'undefined' && backPort !== null) {
            address = backend + ":" + backPort
        } else {
            address = backend + ":9996"
        }
        console.log("Next is " + address)
        next = new services.LandingServiceClient(address, grpc.credentials.createInsecure())
    }

    let address
    if (typeof currentPort !== 'undefined' && currentPort !== null) {
        address = '0.0.0.0:' + currentPort
    } else {
        address = '0.0.0.0:9996'
    }
    let server = new grpc.Server()
    server.addService(services.LandingServiceService, {
        talk: talk,
        talkOneAnswerMore: talkOneAnswerMore,
        talkMoreAnswerOne: talkMoreAnswerOne,
        talkBidirectional: talkBidirectional
    })
    if (typeof secure !== 'undefined' && secure !== null) {
        let credentials = grpc.ServerCredentials.createSsl(
            fs.readFileSync(rootCert),
            [{cert_chain: fs.readFileSync(certChain), private_key: fs.readFileSync(certKey)}],
            true)
        server.bindAsync(address, credentials, () => {
            server.start()
            logger.info("Start GRPC TLS Server:" + address)
        })
    } else {
        server.bindAsync(address, grpc.ServerCredentials.createInsecure(), () => {
            server.start()
            logger.info("Start GRPC Server:" + address)
        })
    }
}

function talk(call, callback) {
    let request = call.request
    logger.info("TALK REQUEST: data=" + request.getData() + ",meta=" + request.getMeta())
    let metadata = propagandaHeaders("Talk", call)
    if (typeof next !== 'undefined' && next !== null) {
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
    logger.info("TalkOneAnswerMore REQUEST: data=" + request.getData() + ",meta=" + request.getMeta())
    let metadata = propagandaHeaders("TalkOneAnswerMore", call)
    if (typeof next !== 'undefined' && next !== null) {
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
            logger.info("TalkOneAnswerMore:" + response)
            call.write(response)
        }
        call.end()
    }
}

function talkMoreAnswerOne(call, callback) {
    let metadata = propagandaHeaders("TalkMoreAnswerOne", call)
    if (typeof next !== 'undefined' && next !== null) {
        let nextCall = next.talkMoreAnswerOne(function (err, response) {
            callback(null, response)
        })
        call.on('data', function (request) {
            logger.info("TalkMoreAnswerOne REQUEST: data=" + request.getData() + ",meta=" + request.getMeta())
            nextCall.write(request, metadata)
        })
        call.on('end', function () {
            nextCall.end()
        })
    } else {
        let talkResults = []
        call.on('data', function (request) {
            logger.info("TalkMoreAnswerOne REQUEST: data=" + request.getData() + ",meta=" + request.getMeta())
            talkResults.push(buildResult(request.getData()))
        })
        call.on('end', function () {
            let response = new messages.TalkResponse()
            response.setStatus(200)
            response.setResultsList(talkResults)
            callback(null, response)
        })
    }
}

function talkBidirectional(call) {
    let metadata = propagandaHeaders("TalkBidirectional", call)
    if (typeof next !== 'undefined' && next !== null) {
        let nextCall = next.talkBidirectional()
        nextCall.on('data', function (response) {
            call.write(response)
        })
        nextCall.on('end', function () {
            call.end()
        })

        call.on('data', function (request) {
            nextCall.write(request, metadata)
        })
        call.on('end', function () {
            nextCall.end()
        })
    } else {
        call.on('data', function (request) {
            logger.info("TalkBidirectional REQUEST: data=" + request.getData() + ",meta=" + request.getMeta())
            let response = new messages.TalkResponse()
            response.setStatus(200)
            let data = request.getData()
            const talkResult = buildResult(data)
            let talkResults = [talkResult]
            response.setResultsList(talkResults)
            logger.info("TalkBidirectional:" + response)
            call.write(response)
        })
        call.on('end', function () {
            call.end()
        })
    }
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
        logger.info(methodName + " HEADER: " + key + ":" + headers[key])
        if (key in tracingKeys) {
            metadata.add(key, headers[key])
        }
    }
    return metadata
}

main()