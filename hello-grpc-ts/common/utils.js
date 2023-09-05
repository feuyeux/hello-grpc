"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildLinkRequests = exports.ans = exports.hellos = void 0;
var landing_pb_1 = require("./landing_pb");
var fast_linked_list_1 = require("fast-linked-list");
exports.hellos = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"];
exports.ans = new Map();
exports.ans.set("你好", "非常感谢");
exports.ans.set("Hello", "Thank you very much");
exports.ans.set("Bonjour", "Merci beaucoup");
exports.ans.set("Hola", "Muchas Gracias");
exports.ans.set("こんにちは", "どうも ありがとう ございます");
exports.ans.set("Ciao", "Mille Grazie");
exports.ans.set("안녕하세요", "대단히 감사합니다");
function randomId(max) {
    return Math.floor(Math.random() * Math.floor(max)).toString();
}
function buildLinkRequests() {
    var requests = new fast_linked_list_1.LinkedList();
    for (var i = 0; i < 3; i++) {
        var request = new landing_pb_1.TalkRequest();
        request.setData(randomId(5));
        request.setMeta("NODEJS");
        requests.push(request);
    }
    return requests.toArray();
}
exports.buildLinkRequests = buildLinkRequests;
