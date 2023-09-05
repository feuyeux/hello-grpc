import {TalkRequest} from "./landing_pb"
import {LinkedList} from "fast-linked-list";

export const hellos: string[] = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"]
export const ans: Map<string, string> = new Map<string, string>()
ans.set("你好", "非常感谢")
ans.set("Hello", "Thank you very much")
ans.set("Bonjour", "Merci beaucoup")
ans.set("Hola", "Muchas Gracias")
ans.set("こんにちは", "どうも ありがとう ございます")
ans.set("Ciao", "Mille Grazie")
ans.set("안녕하세요", "대단히 감사합니다")

function randomId(max: number) {
    return Math.floor(Math.random() * Math.floor(max)).toString()
}

export function buildLinkRequests(): TalkRequest[] {
    const requests = new LinkedList<TalkRequest>()
    for (let i = 0; i < 3; i++) {
        let request = new TalkRequest()
        request.setData(randomId(5))
        request.setMeta("NODEJS")
        requests.push(request)
    }
    return requests.toArray()
}