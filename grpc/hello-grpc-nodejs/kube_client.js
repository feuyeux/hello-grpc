let grpc = require('@grpc/grpc-js')
let sleep = require('sleep')
let messages = require('./common/landing_pb')
let services = require('./common/landing_grpc_pb')


function grpcServer() {
    let server = process.env.GRPC_SERVER
    if (typeof server !== 'undefined' && server !== null) {
        return server
    } else {
        return "localhost"
    }
}

function talk(client, request) {
    client.talk(request, function (err, response) {
        let result = response.getResultsList()[0]
        let kvMap = result.getKvMap()
        console.log("Talk:" + kvMap.get("meta"))
    })
}

function main() {
    let address = grpcServer() + ":9996"
    let c = new services.LandingServiceClient(address, grpc.credentials.createInsecure())

    let request = new messages.TalkRequest()
    request.setData("0")
    request.setMeta("NODEJS")
    talk(c, request)
}

main()