//
//  Generated code. Do not modify.
//  source: landing.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'landing.pb.dart' as $0;

export 'landing.pb.dart';

@$pb.GrpcServiceName('hello.LandingService')
class LandingServiceClient extends $grpc.Client {
  static final _$talk = $grpc.ClientMethod<$0.TalkRequest, $0.TalkResponse>(
      '/hello.LandingService/Talk',
      ($0.TalkRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.TalkResponse.fromBuffer(value));
  static final _$talkOneAnswerMore = $grpc.ClientMethod<$0.TalkRequest, $0.TalkResponse>(
      '/hello.LandingService/TalkOneAnswerMore',
      ($0.TalkRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.TalkResponse.fromBuffer(value));
  static final _$talkMoreAnswerOne = $grpc.ClientMethod<$0.TalkRequest, $0.TalkResponse>(
      '/hello.LandingService/TalkMoreAnswerOne',
      ($0.TalkRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.TalkResponse.fromBuffer(value));
  static final _$talkBidirectional = $grpc.ClientMethod<$0.TalkRequest, $0.TalkResponse>(
      '/hello.LandingService/TalkBidirectional',
      ($0.TalkRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.TalkResponse.fromBuffer(value));

  LandingServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.TalkResponse> talk($0.TalkRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$talk, request, options: options);
  }

  $grpc.ResponseStream<$0.TalkResponse> talkOneAnswerMore($0.TalkRequest request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$talkOneAnswerMore, $async.Stream.fromIterable([request]), options: options);
  }

  $grpc.ResponseFuture<$0.TalkResponse> talkMoreAnswerOne($async.Stream<$0.TalkRequest> request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$talkMoreAnswerOne, request, options: options).single;
  }

  $grpc.ResponseStream<$0.TalkResponse> talkBidirectional($async.Stream<$0.TalkRequest> request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$talkBidirectional, request, options: options);
  }
}

@$pb.GrpcServiceName('hello.LandingService')
abstract class LandingServiceBase extends $grpc.Service {
  $core.String get $name => 'hello.LandingService';

  LandingServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.TalkRequest, $0.TalkResponse>(
        'Talk',
        talk_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.TalkRequest.fromBuffer(value),
        ($0.TalkResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TalkRequest, $0.TalkResponse>(
        'TalkOneAnswerMore',
        talkOneAnswerMore_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.TalkRequest.fromBuffer(value),
        ($0.TalkResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TalkRequest, $0.TalkResponse>(
        'TalkMoreAnswerOne',
        talkMoreAnswerOne,
        true,
        false,
        ($core.List<$core.int> value) => $0.TalkRequest.fromBuffer(value),
        ($0.TalkResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TalkRequest, $0.TalkResponse>(
        'TalkBidirectional',
        talkBidirectional,
        true,
        true,
        ($core.List<$core.int> value) => $0.TalkRequest.fromBuffer(value),
        ($0.TalkResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.TalkResponse> talk_Pre($grpc.ServiceCall call, $async.Future<$0.TalkRequest> request) async {
    return talk(call, await request);
  }

  $async.Stream<$0.TalkResponse> talkOneAnswerMore_Pre($grpc.ServiceCall call, $async.Future<$0.TalkRequest> request) async* {
    yield* talkOneAnswerMore(call, await request);
  }

  $async.Future<$0.TalkResponse> talk($grpc.ServiceCall call, $0.TalkRequest request);
  $async.Stream<$0.TalkResponse> talkOneAnswerMore($grpc.ServiceCall call, $0.TalkRequest request);
  $async.Future<$0.TalkResponse> talkMoreAnswerOne($grpc.ServiceCall call, $async.Stream<$0.TalkRequest> request);
  $async.Stream<$0.TalkResponse> talkBidirectional($grpc.ServiceCall call, $async.Stream<$0.TalkRequest> request);
}
