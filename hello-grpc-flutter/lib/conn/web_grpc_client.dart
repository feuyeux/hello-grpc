import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fixnum/fixnum.dart';
import '../common/landing.pb.dart';
import '../common/common.dart';

class WebGrpcClient {
  final String baseUrl;
  
  WebGrpcClient(String host, int port) : baseUrl = 'http://$host:9997'; // 连接到HTTP网关
  
  Future<TalkResponse> talk(TalkRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/talk'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'data': request.data,
        'meta': request.meta,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _buildTalkResponseFromJson(data);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
  
  Stream<TalkResponse> talkOneAnswerMore(TalkRequest request) async* {
    final response = await http.post(
      Uri.parse('$baseUrl/api/talkOneAnswerMore'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'data': request.data,
        'meta': request.meta,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> results = data['results'] ?? [];
      for (final result in results) {
        yield _buildTalkResponseFromJson(result);
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
  
  Future<TalkResponse> talkMoreAnswerOne(Stream<TalkRequest> requests) async {
    final List<Map<String, dynamic>> requestList = [];
    await for (final request in requests) {
      requestList.add({
        'data': request.data,
        'meta': request.meta,
      });
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl/api/talkMoreAnswerOne'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'requests': requestList}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _buildTalkResponseFromJson(data);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
  
  Stream<TalkResponse> talkBidirectional(Stream<TalkRequest> requests) async* {
    final List<Map<String, dynamic>> requestList = [];
    await for (final request in requests) {
      requestList.add({
        'data': request.data,
        'meta': request.meta,
      });
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl/api/talkBidirectional'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'requests': requestList}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> results = data['results'] ?? [];
      for (final result in results) {
        yield _buildTalkResponseFromJson(result);
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
  
  TalkResponse _buildTalkResponseFromJson(Map<String, dynamic> data) {
    final response = TalkResponse()
      ..status = data['status'] ?? 200;
    
    final List<dynamic> results = data['results'] ?? [];
    for (final resultData in results) {
      final result = TalkResult()
        ..id = Int64.parseInt(resultData['id']?.toString() ?? '0')
        ..type = _parseResultType(resultData['type']);
      
      // 处理kv映射
      final Map<String, dynamic> kv = resultData['kv'] ?? {};
      kv.forEach((key, value) {
        result.kv[key] = value.toString();
      });
      
      response.results.add(result);
    }
    
    return response;
  }
  
  ResultType _parseResultType(dynamic type) {
    if (type == null) return ResultType.OK;
    if (type is String) {
      switch (type.toUpperCase()) {
        case 'OK':
          return ResultType.OK;
        case 'FAIL':
          return ResultType.FAIL;
        default:
          return ResultType.OK;
      }
    }
    if (type is int) {
      return type == 0 ? ResultType.OK : ResultType.FAIL;
    }
    return ResultType.OK;
  }
}
}
