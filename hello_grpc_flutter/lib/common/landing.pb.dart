//
//  Generated code. Do not modify.
//  source: landing.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'landing.pbenum.dart';

export 'landing.pbenum.dart';

class TalkRequest extends $pb.GeneratedMessage {
  factory TalkRequest({
    $core.String? data,
    $core.String? meta,
  }) {
    final $result = create();
    if (data != null) {
      $result.data = data;
    }
    if (meta != null) {
      $result.meta = meta;
    }
    return $result;
  }
  TalkRequest._() : super();
  factory TalkRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TalkRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TalkRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'hello'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'data')
    ..aOS(2, _omitFieldNames ? '' : 'meta')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TalkRequest clone() => TalkRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TalkRequest copyWith(void Function(TalkRequest) updates) => super.copyWith((message) => updates(message as TalkRequest)) as TalkRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TalkRequest create() => TalkRequest._();
  TalkRequest createEmptyInstance() => create();
  static $pb.PbList<TalkRequest> createRepeated() => $pb.PbList<TalkRequest>();
  @$core.pragma('dart2js:noInline')
  static TalkRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TalkRequest>(create);
  static TalkRequest? _defaultInstance;

  /// language index
  @$pb.TagNumber(1)
  $core.String get data => $_getSZ(0);
  @$pb.TagNumber(1)
  set data($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => clearField(1);

  /// clientside language
  @$pb.TagNumber(2)
  $core.String get meta => $_getSZ(1);
  @$pb.TagNumber(2)
  set meta($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMeta() => $_has(1);
  @$pb.TagNumber(2)
  void clearMeta() => clearField(2);
}

class TalkResponse extends $pb.GeneratedMessage {
  factory TalkResponse({
    $core.int? status,
    $core.Iterable<TalkResult>? results,
  }) {
    final $result = create();
    if (status != null) {
      $result.status = status;
    }
    if (results != null) {
      $result.results.addAll(results);
    }
    return $result;
  }
  TalkResponse._() : super();
  factory TalkResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TalkResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TalkResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'hello'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'status', $pb.PbFieldType.O3)
    ..pc<TalkResult>(2, _omitFieldNames ? '' : 'results', $pb.PbFieldType.PM, subBuilder: TalkResult.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TalkResponse clone() => TalkResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TalkResponse copyWith(void Function(TalkResponse) updates) => super.copyWith((message) => updates(message as TalkResponse)) as TalkResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TalkResponse create() => TalkResponse._();
  TalkResponse createEmptyInstance() => create();
  static $pb.PbList<TalkResponse> createRepeated() => $pb.PbList<TalkResponse>();
  @$core.pragma('dart2js:noInline')
  static TalkResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TalkResponse>(create);
  static TalkResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get status => $_getIZ(0);
  @$pb.TagNumber(1)
  set status($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<TalkResult> get results => $_getList(1);
}

class TalkResult extends $pb.GeneratedMessage {
  factory TalkResult({
    $fixnum.Int64? id,
    ResultType? type,
    $core.Map<$core.String, $core.String>? kv,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (type != null) {
      $result.type = type;
    }
    if (kv != null) {
      $result.kv.addAll(kv);
    }
    return $result;
  }
  TalkResult._() : super();
  factory TalkResult.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TalkResult.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TalkResult', package: const $pb.PackageName(_omitMessageNames ? '' : 'hello'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..e<ResultType>(2, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: ResultType.OK, valueOf: ResultType.valueOf, enumValues: ResultType.values)
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'kv', entryClassName: 'TalkResult.KvEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('hello'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TalkResult clone() => TalkResult()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TalkResult copyWith(void Function(TalkResult) updates) => super.copyWith((message) => updates(message as TalkResult)) as TalkResult;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TalkResult create() => TalkResult._();
  TalkResult createEmptyInstance() => create();
  static $pb.PbList<TalkResult> createRepeated() => $pb.PbList<TalkResult>();
  @$core.pragma('dart2js:noInline')
  static TalkResult getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TalkResult>(create);
  static TalkResult? _defaultInstance;

  /// timestamp
  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  /// enum
  @$pb.TagNumber(2)
  ResultType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(ResultType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);

  /// id:result uuid
  /// idx:language index
  /// data: hello
  /// meta: serverside language
  @$pb.TagNumber(3)
  $core.Map<$core.String, $core.String> get kv => $_getMap(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
