// GENERATED CODE -- DO NOT EDIT!

'use strict';
var grpc = require('@grpc/grpc-js');
var landing_pb = require('./landing_pb.js');

function serialize_hello_TalkRequest(arg) {
  if (!(arg instanceof landing_pb.TalkRequest)) {
    throw new Error('Expected argument of type hello.TalkRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_hello_TalkRequest(buffer_arg) {
  return landing_pb.TalkRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_hello_TalkResponse(arg) {
  if (!(arg instanceof landing_pb.TalkResponse)) {
    throw new Error('Expected argument of type hello.TalkResponse');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_hello_TalkResponse(buffer_arg) {
  return landing_pb.TalkResponse.deserializeBinary(new Uint8Array(buffer_arg));
}


var LandingServiceService = exports.LandingServiceService = {
  // Unary RPC
talk: {
    path: '/hello.LandingService/Talk',
    requestStream: false,
    responseStream: false,
    requestType: landing_pb.TalkRequest,
    responseType: landing_pb.TalkResponse,
    requestSerialize: serialize_hello_TalkRequest,
    requestDeserialize: deserialize_hello_TalkRequest,
    responseSerialize: serialize_hello_TalkResponse,
    responseDeserialize: deserialize_hello_TalkResponse,
  },
  // Server streaming RPC
talkOneAnswerMore: {
    path: '/hello.LandingService/TalkOneAnswerMore',
    requestStream: false,
    responseStream: true,
    requestType: landing_pb.TalkRequest,
    responseType: landing_pb.TalkResponse,
    requestSerialize: serialize_hello_TalkRequest,
    requestDeserialize: deserialize_hello_TalkRequest,
    responseSerialize: serialize_hello_TalkResponse,
    responseDeserialize: deserialize_hello_TalkResponse,
  },
  // Client streaming RPC with random & sleep
talkMoreAnswerOne: {
    path: '/hello.LandingService/TalkMoreAnswerOne',
    requestStream: true,
    responseStream: false,
    requestType: landing_pb.TalkRequest,
    responseType: landing_pb.TalkResponse,
    requestSerialize: serialize_hello_TalkRequest,
    requestDeserialize: deserialize_hello_TalkRequest,
    responseSerialize: serialize_hello_TalkResponse,
    responseDeserialize: deserialize_hello_TalkResponse,
  },
  // Bidirectional streaming RPC
talkBidirectional: {
    path: '/hello.LandingService/TalkBidirectional',
    requestStream: true,
    responseStream: true,
    requestType: landing_pb.TalkRequest,
    responseType: landing_pb.TalkResponse,
    requestSerialize: serialize_hello_TalkRequest,
    requestDeserialize: deserialize_hello_TalkRequest,
    responseSerialize: serialize_hello_TalkResponse,
    responseDeserialize: deserialize_hello_TalkResponse,
  },
};

exports.LandingServiceClient = grpc.makeGenericClientConstructor(LandingServiceService, 'LandingService');
