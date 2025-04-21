"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g = Object.create((typeof Iterator === "function" ? Iterator : Object).prototype);
    return g.next = verb(0), g["throw"] = verb(1), g["return"] = verb(2), typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
Object.defineProperty(exports, "__esModule", { value: true });
var grpc = require("@grpc/grpc-js");
var landing_grpc_pb_1 = require("./common/landing_grpc_pb");
var landing_pb_1 = require("./common/landing_pb");
var conn_1 = require("./common/conn");
var utils_1 = require("./common/utils");
var client;
// Unary
function talk(request) {
    conn_1.logger.info("Unary RPC");
    conn_1.logger.info("Talk->" + request);
    return new Promise(function (resolve, reject) {
        client.talk(request, function (err, response) {
            if (err) {
                return reject(err);
            }
            printResponse("Talk<-", response);
            return resolve(response);
        });
    });
}
// Server streaming
function talkOneAnswerMore(request) {
    conn_1.logger.info("Server streaming RPC");
    conn_1.logger.info("TalkOneAnswerMore->" + request);
    var metadata = new grpc.Metadata();
    metadata.add("k1", "v1");
    metadata.add("k2", "v2");
    return new Promise(function (resolve, reject) {
        var stream = client.talkOneAnswerMore(request, metadata);
        stream.on('data', function (response) {
            printResponse("TalkOneAnswerMore<-", response);
        });
        stream.on('end', resolve);
        stream.on('error', reject);
    });
}
// Client streaming
function talkMoreAnswerOne(requests) {
    return __awaiter(this, void 0, void 0, function () {
        var metadata, call;
        return __generator(this, function (_a) {
            conn_1.logger.info("Client streaming RPC");
            metadata = new grpc.Metadata();
            metadata.add("k1", "v1");
            metadata.add("k2", "v2");
            call = client.talkMoreAnswerOne(metadata, function (err, response) {
                if (err) {
                    conn_1.logger.error(err);
                }
                else {
                    printResponse("TalkMoreAnswerOne<-", response);
                }
            });
            call.on('error', function (e) {
                conn_1.logger.error(e);
            });
            requests.forEach(function (request) {
                conn_1.logger.info("TalkMoreAnswerOne->" + request);
                // call.write(request, metadata)
                call.write(request);
            });
            call.end();
            return [2 /*return*/];
        });
    });
}
// Bidirectional streaming
function talkBidirectional(requests) {
    return __awaiter(this, void 0, void 0, function () {
        var metadata, call;
        return __generator(this, function (_a) {
            conn_1.logger.info("Bidirectional streaming RPC");
            metadata = new grpc.Metadata();
            metadata.add("k1", "v1");
            metadata.add("k2", "v2");
            call = client.talkBidirectional(metadata);
            call.on('data', function (response) {
                printResponse("TalkBidirectional<-", response);
            });
            call.on('error', function (e) {
                conn_1.logger.error(e);
            });
            requests.forEach(function (request) {
                conn_1.logger.info("TalkBidirectional->" + request);
                // call.write(request, metadata)
                call.write(request);
            });
            call.end();
            return [2 /*return*/];
        });
    });
}
function printResponse(methodName, response) {
    if (response !== undefined) {
        var resultsList = response.getResultsList();
        if (resultsList !== undefined) {
            resultsList.forEach(function (result) {
                var kv = result.getKvMap();
                conn_1.logger.info("%s[%d] %d [%s %s %s,%s:%s]", methodName, response.getStatus(), result.getId(), kv.get("meta"), result.getType(), kv.get("id"), kv.get("idx"), kv.get("data"));
            });
        }
    }
}
function grpcServerHost() {
    var server = process.env.GRPC_SERVER;
    // @ts-ignore
    return typeof server !== "undefined" && server !== null ? server : "localhost";
}
function startClient() {
    return __awaiter(this, void 0, void 0, function () {
        var connectTo, request;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    connectTo = grpcServerHost() + ":" + conn_1.port;
                    conn_1.logger.info("connectTo:%s", connectTo);
                    client = new landing_grpc_pb_1.LandingServiceClient(connectTo, grpc.credentials.createInsecure());
                    request = new landing_pb_1.TalkRequest();
                    request.setData("0");
                    request.setMeta("TypeScript");
                    //
                    return [4 /*yield*/, talk(request)
                        //
                    ];
                case 1:
                    //
                    _a.sent();
                    //
                    request.setData("0,1,2");
                    return [4 /*yield*/, talkOneAnswerMore(request)
                        //
                    ];
                case 2:
                    _a.sent();
                    //
                    return [4 /*yield*/, talkMoreAnswerOne((0, utils_1.buildLinkRequests)())];
                case 3:
                    //
                    _a.sent();
                    return [4 /*yield*/, talkBidirectional((0, utils_1.buildLinkRequests)())];
                case 4:
                    _a.sent();
                    return [2 /*return*/];
            }
        });
    });
}
startClient().then(function (r) { return console.log('Bye 🍎hello client🍎'); });
