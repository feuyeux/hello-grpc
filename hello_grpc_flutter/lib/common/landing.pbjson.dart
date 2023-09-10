//
//  Generated code. Do not modify.
//  source: landing.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use resultTypeDescriptor instead')
const ResultType$json = {
  '1': 'ResultType',
  '2': [
    {'1': 'OK', '2': 0},
    {'1': 'FAIL', '2': 1},
  ],
};

/// Descriptor for `ResultType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List resultTypeDescriptor = $convert.base64Decode(
    'CgpSZXN1bHRUeXBlEgYKAk9LEAASCAoERkFJTBAB');

@$core.Deprecated('Use talkRequestDescriptor instead')
const TalkRequest$json = {
  '1': 'TalkRequest',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 9, '10': 'data'},
    {'1': 'meta', '3': 2, '4': 1, '5': 9, '10': 'meta'},
  ],
};

/// Descriptor for `TalkRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List talkRequestDescriptor = $convert.base64Decode(
    'CgtUYWxrUmVxdWVzdBISCgRkYXRhGAEgASgJUgRkYXRhEhIKBG1ldGEYAiABKAlSBG1ldGE=');

@$core.Deprecated('Use talkResponseDescriptor instead')
const TalkResponse$json = {
  '1': 'TalkResponse',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 5, '10': 'status'},
    {'1': 'results', '3': 2, '4': 3, '5': 11, '6': '.hello.TalkResult', '10': 'results'},
  ],
};

/// Descriptor for `TalkResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List talkResponseDescriptor = $convert.base64Decode(
    'CgxUYWxrUmVzcG9uc2USFgoGc3RhdHVzGAEgASgFUgZzdGF0dXMSKwoHcmVzdWx0cxgCIAMoCz'
    'IRLmhlbGxvLlRhbGtSZXN1bHRSB3Jlc3VsdHM=');

@$core.Deprecated('Use talkResultDescriptor instead')
const TalkResult$json = {
  '1': 'TalkResult',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'type', '3': 2, '4': 1, '5': 14, '6': '.hello.ResultType', '10': 'type'},
    {'1': 'kv', '3': 3, '4': 3, '5': 11, '6': '.hello.TalkResult.KvEntry', '10': 'kv'},
  ],
  '3': [TalkResult_KvEntry$json],
};

@$core.Deprecated('Use talkResultDescriptor instead')
const TalkResult_KvEntry$json = {
  '1': 'KvEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `TalkResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List talkResultDescriptor = $convert.base64Decode(
    'CgpUYWxrUmVzdWx0Eg4KAmlkGAEgASgDUgJpZBIlCgR0eXBlGAIgASgOMhEuaGVsbG8uUmVzdW'
    'x0VHlwZVIEdHlwZRIpCgJrdhgDIAMoCzIZLmhlbGxvLlRhbGtSZXN1bHQuS3ZFbnRyeVICa3Ya'
    'NQoHS3ZFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

