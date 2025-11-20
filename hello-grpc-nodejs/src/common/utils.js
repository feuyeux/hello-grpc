const { LinkedList } = require("fast-linked-list");
const { TalkRequest } = require("../proto/landing_pb");

const hellos = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"];

const ans = new Map();
ans.set("你好", "非常感谢");
ans.set("Hello", "Thank you very much");
ans.set("Bonjour", "Merci beaucoup");
ans.set("Hola", "Muchas Gracias");
ans.set("こんにちは", "どうも ありがとう ございます");
ans.set("Ciao", "Mille Grazie");
ans.set("안녕하세요", "대단히 감사합니다");

function getAns() {
    return ans;
}

function buildLinkRequests() {
    const requests = new LinkedList();
    for (let i = 0; i < 3; i++) {
        const request = new TalkRequest();
        request.setData(randomId(5));
        request.setMeta("NODEJS");
        requests.push(request);
    }
    return requests;
}

function randomId(max) {
    return Math.floor(Math.random() * Math.floor(max)).toString();
}

function getVersion() {
    try {
        const grpcJsVersion = require('@grpc/grpc-js/package.json').version;
        return `grpc.version=${grpcJsVersion}`;
    } catch (error) {
        console.error('Error getting gRPC version:', error);
        return 'grpc.version=unknown';
    }
}

exports.hellos = hellos;
exports.ans = getAns;
exports.buildLinkRequests = buildLinkRequests;
exports.randomId = randomId;
exports.getVersion = getVersion;