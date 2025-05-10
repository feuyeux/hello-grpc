const { LinkedList } = require("fast-linked-list")
const { TalkRequest } = require("./landing_pb")
const grpc = require('@grpc/grpc-js')
const fs = require('fs')
const path = require('path')

const hellos = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"]
const ans = new Map()
ans.set("你好", "非常感谢")
ans.set("Hello", "Thank you very much")
ans.set("Bonjour", "Merci beaucoup")
ans.set("Hola", "Muchas Gracias")
ans.set("こんにちは", "どうも ありがとう ございます")
ans.set("Ciao", "Mille Grazie")
ans.set("안녕하세요", "대단히 감사합니다")

function getAns() {
    return ans
}

function buildLinkRequests() {
    const requests = new LinkedList()
    for (let i = 0; i < 3; i++) {
        let request = new TalkRequest()
        request.setData(randomId(5))
        request.setMeta("NODEJS")
        requests.push(request)
    }
    return requests
}

function randomId(max) {
    return Math.floor(Math.random() * Math.floor(max)).toString()
}

function getVersion() {
    // For Node.js gRPC, we should return the actual gRPC version
    // instead of parsing package.json

    // Access the version directly from the grpc object if available
    if (grpc.version) {
        return `grpc.version=${grpc.version}`
    }

    // For @grpc/grpc-js which doesn't expose version directly,
    // try to access it from the module's internal state
    try {
        const grpcJsVersion = require('@grpc/grpc-js/package.json').version
        return `grpc.version=${grpcJsVersion}`
    } catch (error) {
        // Fallback if we can't get the version programmatically
        console.error('Error getting gRPC version:', error)
    }

    // Final fallback with a meaningful version string
    return `grpc.version=unknown`
}

exports.hellos = hellos
exports.ans = getAns
exports.buildLinkRequests = buildLinkRequests
exports.getVersion = getVersion