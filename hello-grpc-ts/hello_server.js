"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
var grpc = require("@grpc/grpc-js");
var landing_grpc_pb_1 = require("./common/landing_grpc_pb");
var landing_pb_1 = require("./common/landing_pb");
var uuid_1 = require("uuid");
var utils_1 = require("./common/utils");
var conn_1 = require("./common/conn");
var tracingKeys = [
    "x-request-id",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-ot-span-context"
];
function buildResult(data) {
    var result = new landing_pb_1.TalkResult();
    var index = parseInt(data);
    var hello = utils_1.hellos[index];
    result.setId(Math.round(Date.now() / 1000));
    result.setType(landing_pb_1.ResultType.OK);
    var kv = result.getKvMap();
    kv.set("id", (0, uuid_1.v4)());
    kv.set("idx", data);
    kv.set("data", hello + "," + utils_1.ans.get(hello));
    kv.set("meta", "TypeScript");
    return result;
}
var HelloServer = /** @class */ (function () {
    function HelloServer() {
    }
    HelloServer.prototype.talk = function (call, callback) {
        var data = call.request.getData();
        var meta = call.request.getMeta();
        conn_1.logger.info("TALK REQUEST: data=%s,meta=%s", data, meta);
        var headers = call.metadata.getMap();
        var metadata = propagandaHeaders("Talk", headers);
        if (metadata.getMap.length > 0) {
            conn_1.logger.info("TALK TRACING HEADERS: %s", metadata);
        }
        var response = new landing_pb_1.TalkResponse();
        response.setStatus(200);
        var talkResult = buildResult(data);
        var talkResults = [talkResult];
        response.setResultsList(talkResults);
        callback(null, response);
    };
    HelloServer.prototype.talkMoreAnswerOne = function (call, callback) {
        var headers = call.metadata.getMap();
        var metadata = propagandaHeaders("TalkMoreAnswerOne", headers);
        if (metadata.getMap.length > 0) {
            conn_1.logger.info("TalkMoreAnswerOne TRACING HEADERS: %s", metadata);
        }
        var talkResults = [];
        call.on('data', function (request) {
            conn_1.logger.info("TalkMoreAnswerOne REQUEST: data=%s,meta=%s", request.getData(), request.getMeta());
            talkResults.push(buildResult(request.getData()));
        });
        call.on('end', function () {
            var response = new landing_pb_1.TalkResponse();
            response.setStatus(200);
            response.setResultsList(talkResults);
            callback(null, response);
        });
        call.on('error', function (e) {
            conn_1.logger.error(e);
        });
    };
    HelloServer.prototype.talkOneAnswerMore = function (call) {
        var request = call.request;
        conn_1.logger.info("TalkOneAnswerMore REQUEST: data=%s,meta=%s", request.getData(), request.getMeta());
        var headers = call.metadata.getMap();
        var metadata = propagandaHeaders("TalkOneAnswerMore", headers);
        if (metadata.getMap.length > 0) {
            conn_1.logger.info("TalkOneAnswerMore TRACING HEADERS: %s", metadata);
        }
        var datas = request.getData().split(",");
        for (var data in datas) {
            var response = new landing_pb_1.TalkResponse();
            response.setStatus(200);
            var talkResult = buildResult(data);
            var talkResults = [talkResult];
            response.setResultsList(talkResults);
            conn_1.logger.info("TalkOneAnswerMore:%s", response);
            call.write(response);
        }
        call.end();
    };
    HelloServer.prototype.talkBidirectional = function (call) {
        var headers = call.metadata.getMap();
        var metadata = propagandaHeaders("TalkBidirectional", headers);
        if (metadata.getMap.length > 0) {
            conn_1.logger.info("TalkBidirectional TRACING HEADERS: %s", metadata);
        }
        call.on('data', function (request) {
            conn_1.logger.info("TalkBidirectional REQUEST: data=%s,meta=%s", request.getData(), request.getMeta());
            var response = new landing_pb_1.TalkResponse();
            response.setStatus(200);
            var data = request.getData();
            var talkResult = buildResult(data);
            var talkResults = [talkResult];
            response.setResultsList(talkResults);
            conn_1.logger.info("TalkBidirectional:%s", response);
            call.write(response);
        });
        call.on('end', function () {
            call.end();
        });
    };
    return HelloServer;
}());
function propagandaHeaders(methodName, headers) {
    var metadata = new grpc.Metadata();
    for (var key in headers) {
        var value = headers[key];
        conn_1.logger.info("%s HEADER: %s:%s", methodName, key, value);
        if (key in tracingKeys) {
            metadata.add(key, value);
        }
    }
    return metadata;
}
function startServer() {
    var server = new grpc.Server();
    server.addService(landing_grpc_pb_1.LandingServiceService, new HelloServer());
    server.bindAsync("0.0.0.0:" + conn_1.port, grpc.ServerCredentials.createInsecure(), function (error, port) {
        if (error) {
            conn_1.logger.error("Fail to start GRPC Server[%s]", port, error);
        }
        server.start();
        conn_1.logger.info("Start GRPC Server[%s]", port);
    });
}
startServer();
