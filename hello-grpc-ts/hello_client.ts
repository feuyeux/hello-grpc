import * as grpc from '@grpc/grpc-js'
import { LandingServiceClient } from "./common/landing_grpc_pb"
import { TalkRequest, TalkResponse } from "./common/landing_pb"
import { logger, port } from "./common/conn";
import { buildLinkRequests } from "./common/utils";

let client: LandingServiceClient

// Unary
function talk(request: TalkRequest): Promise<TalkResponse> {
    logger.info("Unary RPC")
    logger.info("Talk->" + request)
    return new Promise<TalkResponse>((resolve, reject) => {
        client.talk(request, (err, response) => {
            if (err) {
                return reject(err)
            }
            printResponse("Talk<-", response)
            return resolve(response)
        })
    })
}

// Server streaming
function talkOneAnswerMore(request: TalkRequest): Promise<void> {
    logger.info("Server streaming RPC")
    logger.info("TalkOneAnswerMore->" + request)
    const metadata = new grpc.Metadata()
    metadata.add("k1", "v1")
    metadata.add("k2", "v2")
    return new Promise<void>((resolve, reject) => {
        let stream = client.talkOneAnswerMore(request, metadata)
        stream.on('data', function (response) {
            printResponse("TalkOneAnswerMore<-", response)
        })
        stream.on('end', resolve);
        stream.on('error', reject);
    });
}

// Client streaming
async function talkMoreAnswerOne(requests: TalkRequest[]) {
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

// Bidirectional streaming
async function talkBidirectional(requests: TalkRequest[]) {
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


function printResponse(methodName: string, response: TalkResponse) {
    if (response !== undefined) {
        let resultsList = response.getResultsList()
        if (resultsList !== undefined) {
            resultsList.forEach((result: { getKvMap: () => any; getId: () => any; getType: () => any; }) => {
                let kv = result.getKvMap()
                logger.info("%s[%d] %d [%s %s %s,%s:%s]", methodName,
                    response.getStatus(), result.getId(), kv.get("meta"), result.getType(), kv.get("id"),
                    kv.get("idx"), kv.get("data"))
            })
        }
    }
}

async function startClient() {
    client = new LandingServiceClient(
        `localhost:${port}`,
        grpc.credentials.createInsecure(),
    )

    let request = new TalkRequest()
    request.setData("0")
    request.setMeta("TypeScript")
    //
    await talk(request)
    //
    request.setData("0,1,2")
    await talkOneAnswerMore(request)
    //
    await talkMoreAnswerOne(buildLinkRequests())

    await talkBidirectional(buildLinkRequests())
}


startClient().then(r => console.log('Bye 🍎hello client🍎'))