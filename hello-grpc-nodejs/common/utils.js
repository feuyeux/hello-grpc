const {LinkedList} = require("fast-linked-list")
const {TalkRequest} = require("./landing_pb")

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

exports.hellos = hellos
exports.ans = getAns
exports.buildLinkRequests = buildLinkRequests