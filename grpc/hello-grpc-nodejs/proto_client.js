let grpc = require('@grpc/grpc-js')
let messages = require('./common/landing_pb')
let services = require('./common/landing_grpc_pb')
let conn = require('./common/connection')
const fs = require('fs');
const logger = conn.logger

async function main() {
    let c = conn.getClient();
    let request = new messages.TalkRequest()
    request.setData("0")
    request.setMeta("NODEJS")
    talk(c, request)

    request = new messages.TalkRequest()
    request.setData("0,1,2")
    request.setMeta("NODEJS")
    talkOneAnswerMore(c, request)

    let r1 = new messages.TalkRequest()
    r1.setData(randomId(5))
    r1.setMeta("NODEJS")
    let r2 = new messages.TalkRequest()
    r2.setData(randomId(5))
    r2.setMeta("NODEJS")
    let r3 = new messages.TalkRequest()
    r3.setData(randomId(5))
    r3.setMeta("NODEJS")
    let rs = [r1, r2, r3]

    talkMoreAnswerOne(c, rs)

    talkBidirectional(c, rs)
}

function talk(client, request) {
    logger.info("Unary RPC")
    logger.info("Talk->" + request)
    const metadata = new grpc.Metadata()
    metadata.add("k1", "v1")
    metadata.add("k2", "v2")
    client.talk(request, metadata, function (err, response) {
        if (err) {
            logger.error(err)
        } else {
            printResponse("Talk<-", response)
        }
    })
}

function talkMoreAnswerOne(client, requests) {
    logger.info("Client streaming RPC")
    const metadata = new grpc.Metadata()
    metadata.add("k1", "v1")
    metadata.add("k2", "v2")
    let call = client.talkMoreAnswerOne(metadata, function (err, response) {
        if (err) {
            logger.error(err)
        } else {
            printResponse("TalkMoreAnswerOne<-", response)
        }
    })
    call.on('error', function (e) {
        logger.error(e)
    })
    requests.forEach(request => {
        logger.info("TalkMoreAnswerOne->" + request)
        // call.write(request, metadata)
        call.write(request)
    })
    call.end()
}

function talkOneAnswerMore(client, request) {
    logger.info("Server streaming RPC")
    logger.info("TalkOneAnswerMore->" + request)
    const metadata = new grpc.Metadata()
    metadata.add("k1", "v1")
    metadata.add("k2", "v2")
    let call = client.talkOneAnswerMore(request, metadata)

    call.on('data', function (response) {
        printResponse("TalkOneAnswerMore<-", response)
    })
    call.on('error', function (e) {
        logger.error(e)
    })
    call.on('end', function () {
        logger.debug("DONE")
    })
}

function talkBidirectional(client, requests) {
    logger.info("Bidirectional streaming RPC")
    const metadata = new grpc.Metadata()
    metadata.add("k1", "v1")
    metadata.add("k2", "v2")
    let call = client.talkBidirectional(metadata)
    call.on('data', function (response) {
        printResponse("TalkBidirectional<-", response)
    })
    call.on('error', function (e) {
        logger.error(e)
    })
    requests.forEach(request => {
        logger.info("TalkBidirectional->" + request)
        // call.write(request, metadata)
        call.write(request)
    })
    call.end()
}

function randomId(max) {
    return Math.floor(Math.random() * Math.floor(max)).toString()
}

function printResponse(methodName, response) {
    if (response !== undefined) {
        let resultsList = response.getResultsList();
        if (resultsList !== undefined) {
            resultsList.forEach(result => {
                let kv = result.getKvMap()
                logger.info("%s[%d] %d [%s %s %s,%s:%s]", methodName,
                    response.getStatus(), result.getId(), kv.get("meta"), result.getType(), kv.get("id"),
                    kv.get("idx"), kv.get("data"))
            })
        }
    }
}

main()