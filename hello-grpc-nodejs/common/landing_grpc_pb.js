// GENERATED CODE -- DO NOT EDIT!

'use strict';
var grpc = require('@grpc/grpc-js');
var landing_pb = require('./landing_pb.js');

function serialize_org_feuyeux_grpc_TalkRequest(arg) {
  if (!(arg instanceof landing_pb.TalkRequest)) {
    throw new Error('Expected argument of type org.feuyeux.grpc.TalkRequest');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_org_feuyeux_grpc_TalkRequest(buffer_arg) {
  return landing_pb.TalkRequest.deserializeBinary(new Uint8Array(buffer_arg));
}

function serialize_org_feuyeux_grpc_TalkResponse(arg) {
  if (!(arg instanceof landing_pb.TalkResponse)) {
    throw new Error('Expected argument of type org.feuyeux.grpc.TalkResponse');
  }
  return Buffer.from(arg.serializeBinary());
}

function deserialize_org_feuyeux_grpc_TalkResponse(buffer_arg) {
  return landing_pb.TalkResponse.deserializeBinary(new Uint8Array(buffer_arg));
}


var LandingServiceService = exports.LandingServiceService = {
  // Unary RPC
talk: {
    path: '/org.feuyeux.grpc.LandingService/Talk',
    requestStream: false,
    responseStream: false,
    requestType: landing_pb.TalkRequest,
    responseType: landing_pb.TalkResponse,
    requestSerialize: serialize_org_feuyeux_grpc_TalkRequest,
    requestDeserialize: deserialize_org_feuyeux_grpc_TalkRequest,
    responseSerialize: serialize_org_feuyeux_grpc_TalkResponse,
    responseDeserialize: deserialize_org_feuyeux_grpc_TalkResponse,
  },
  // Server streaming RPC
talkOneAnswerMore: {
    path: '/org.feuyeux.grpc.LandingService/TalkOneAnswerMore',
    requestStream: false,
    responseStream: true,
    requestType: landing_pb.TalkRequest,
    responseType: landing_pb.TalkResponse,
    requestSerialize: serialize_org_feuyeux_grpc_TalkRequest,
    requestDeserialize: deserialize_org_feuyeux_grpc_TalkRequest,
    responseSerialize: serialize_org_feuyeux_grpc_TalkResponse,
    responseDeserialize: deserialize_org_feuyeux_grpc_TalkResponse,
  },
  // Client streaming RPC with random & sleep
talkMoreAnswerOne: {
    path: '/org.feuyeux.grpc.LandingService/TalkMoreAnswerOne',
    requestStream: true,
    responseStream: false,
    requestType: landing_pb.TalkRequest,
    responseType: landing_pb.TalkResponse,
    requestSerialize: serialize_org_feuyeux_grpc_TalkRequest,
    requestDeserialize: deserialize_org_feuyeux_grpc_TalkRequest,
    responseSerialize: serialize_org_feuyeux_grpc_TalkResponse,
    responseDeserialize: deserialize_org_feuyeux_grpc_TalkResponse,
  },
  // Bidirectional streaming RPC
talkBidirectional: {
    path: '/org.feuyeux.grpc.LandingService/TalkBidirectional',
    requestStream: true,
    responseStream: true,
    requestType: landing_pb.TalkRequest,
    responseType: landing_pb.TalkResponse,
    requestSerialize: serialize_org_feuyeux_grpc_TalkRequest,
    requestDeserialize: deserialize_org_feuyeux_grpc_TalkRequest,
    responseSerialize: serialize_org_feuyeux_grpc_TalkResponse,
    responseDeserialize: deserialize_org_feuyeux_grpc_TalkResponse,
  },
};

exports.LandingServiceClient = grpc.makeGenericClientConstructor(LandingServiceService);
