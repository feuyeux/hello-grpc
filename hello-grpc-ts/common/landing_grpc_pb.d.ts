// package: hello
// file: landing.proto

/* tslint:disable */
/* eslint-disable */

import * as grpc from "@grpc/grpc-js";
import * as landing_pb from "./landing_pb";

interface ILandingServiceService extends grpc.ServiceDefinition<grpc.UntypedServiceImplementation> {
    talk: ILandingServiceService_ITalk;
    talkOneAnswerMore: ILandingServiceService_ITalkOneAnswerMore;
    talkMoreAnswerOne: ILandingServiceService_ITalkMoreAnswerOne;
    talkBidirectional: ILandingServiceService_ITalkBidirectional;
}

interface ILandingServiceService_ITalk extends grpc.MethodDefinition<landing_pb.TalkRequest, landing_pb.TalkResponse> {
    path: "/hello.LandingService/Talk";
    requestStream: false;
    responseStream: false;
    requestSerialize: grpc.serialize<landing_pb.TalkRequest>;
    requestDeserialize: grpc.deserialize<landing_pb.TalkRequest>;
    responseSerialize: grpc.serialize<landing_pb.TalkResponse>;
    responseDeserialize: grpc.deserialize<landing_pb.TalkResponse>;
}
interface ILandingServiceService_ITalkOneAnswerMore extends grpc.MethodDefinition<landing_pb.TalkRequest, landing_pb.TalkResponse> {
    path: "/hello.LandingService/TalkOneAnswerMore";
    requestStream: false;
    responseStream: true;
    requestSerialize: grpc.serialize<landing_pb.TalkRequest>;
    requestDeserialize: grpc.deserialize<landing_pb.TalkRequest>;
    responseSerialize: grpc.serialize<landing_pb.TalkResponse>;
    responseDeserialize: grpc.deserialize<landing_pb.TalkResponse>;
}
interface ILandingServiceService_ITalkMoreAnswerOne extends grpc.MethodDefinition<landing_pb.TalkRequest, landing_pb.TalkResponse> {
    path: "/hello.LandingService/TalkMoreAnswerOne";
    requestStream: true;
    responseStream: false;
    requestSerialize: grpc.serialize<landing_pb.TalkRequest>;
    requestDeserialize: grpc.deserialize<landing_pb.TalkRequest>;
    responseSerialize: grpc.serialize<landing_pb.TalkResponse>;
    responseDeserialize: grpc.deserialize<landing_pb.TalkResponse>;
}
interface ILandingServiceService_ITalkBidirectional extends grpc.MethodDefinition<landing_pb.TalkRequest, landing_pb.TalkResponse> {
    path: "/hello.LandingService/TalkBidirectional";
    requestStream: true;
    responseStream: true;
    requestSerialize: grpc.serialize<landing_pb.TalkRequest>;
    requestDeserialize: grpc.deserialize<landing_pb.TalkRequest>;
    responseSerialize: grpc.serialize<landing_pb.TalkResponse>;
    responseDeserialize: grpc.deserialize<landing_pb.TalkResponse>;
}

export const LandingServiceService: ILandingServiceService;

export interface ILandingServiceServer extends grpc.UntypedServiceImplementation {
    talk: grpc.handleUnaryCall<landing_pb.TalkRequest, landing_pb.TalkResponse>;
    talkOneAnswerMore: grpc.handleServerStreamingCall<landing_pb.TalkRequest, landing_pb.TalkResponse>;
    talkMoreAnswerOne: grpc.handleClientStreamingCall<landing_pb.TalkRequest, landing_pb.TalkResponse>;
    talkBidirectional: grpc.handleBidiStreamingCall<landing_pb.TalkRequest, landing_pb.TalkResponse>;
}

export interface ILandingServiceClient {
    talk(request: landing_pb.TalkRequest, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientUnaryCall;
    talk(request: landing_pb.TalkRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientUnaryCall;
    talk(request: landing_pb.TalkRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientUnaryCall;
    talkOneAnswerMore(request: landing_pb.TalkRequest, options?: Partial<grpc.CallOptions>): grpc.ClientReadableStream<landing_pb.TalkResponse>;
    talkOneAnswerMore(request: landing_pb.TalkRequest, metadata?: grpc.Metadata, options?: Partial<grpc.CallOptions>): grpc.ClientReadableStream<landing_pb.TalkResponse>;
    talkMoreAnswerOne(callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientWritableStream<landing_pb.TalkRequest>;
    talkMoreAnswerOne(metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientWritableStream<landing_pb.TalkRequest>;
    talkMoreAnswerOne(options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientWritableStream<landing_pb.TalkRequest>;
    talkMoreAnswerOne(metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientWritableStream<landing_pb.TalkRequest>;
    talkBidirectional(): grpc.ClientDuplexStream<landing_pb.TalkRequest, landing_pb.TalkResponse>;
    talkBidirectional(options: Partial<grpc.CallOptions>): grpc.ClientDuplexStream<landing_pb.TalkRequest, landing_pb.TalkResponse>;
    talkBidirectional(metadata: grpc.Metadata, options?: Partial<grpc.CallOptions>): grpc.ClientDuplexStream<landing_pb.TalkRequest, landing_pb.TalkResponse>;
}

export class LandingServiceClient extends grpc.Client implements ILandingServiceClient {
    constructor(address: string, credentials: grpc.ChannelCredentials, options?: Partial<grpc.ClientOptions>);
    public talk(request: landing_pb.TalkRequest, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientUnaryCall;
    public talk(request: landing_pb.TalkRequest, metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientUnaryCall;
    public talk(request: landing_pb.TalkRequest, metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientUnaryCall;
    public talkOneAnswerMore(request: landing_pb.TalkRequest, options?: Partial<grpc.CallOptions>): grpc.ClientReadableStream<landing_pb.TalkResponse>;
    public talkOneAnswerMore(request: landing_pb.TalkRequest, metadata?: grpc.Metadata, options?: Partial<grpc.CallOptions>): grpc.ClientReadableStream<landing_pb.TalkResponse>;
    public talkMoreAnswerOne(callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientWritableStream<landing_pb.TalkRequest>;
    public talkMoreAnswerOne(metadata: grpc.Metadata, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientWritableStream<landing_pb.TalkRequest>;
    public talkMoreAnswerOne(options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientWritableStream<landing_pb.TalkRequest>;
    public talkMoreAnswerOne(metadata: grpc.Metadata, options: Partial<grpc.CallOptions>, callback: (error: grpc.ServiceError | null, response: landing_pb.TalkResponse) => void): grpc.ClientWritableStream<landing_pb.TalkRequest>;
    public talkBidirectional(options?: Partial<grpc.CallOptions>): grpc.ClientDuplexStream<landing_pb.TalkRequest, landing_pb.TalkResponse>;
    public talkBidirectional(metadata?: grpc.Metadata, options?: Partial<grpc.CallOptions>): grpc.ClientDuplexStream<landing_pb.TalkRequest, landing_pb.TalkResponse>;
}
