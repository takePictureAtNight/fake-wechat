import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_config.dart';

class ApiException implements Exception {
  ApiException(this.code, this.message);
  final int code;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String baseUrl = AppConfig.apiBaseUrl;
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  dynamic _decodeBody(http.Response r) {
    if (r.bodyBytes.isEmpty) return null;
    return json.decode(utf8.decode(r.bodyBytes));
  }

  Future<dynamic> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final r = await http.get(uri, headers: _headers);
    return _handle(r);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    final r = await http.post(
      uri,
      headers: _headers,
      body: body == null ? null : json.encode(body),
    );
    return _handle(r);
  }

  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final r = await http.delete(uri, headers: _headers);
    return _handle(r);
  }

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    final r = await http.put(
      uri,
      headers: _headers,
      body: body == null ? null : json.encode(body),
    );
    return _handle(r);
  }

  Future<String> uploadImage(File file) async {
    final uri = Uri.parse('$baseUrl/api/upload/image');
    final req = http.MultipartRequest('POST', uri);
    if (token != null && token!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await req.send();
    final r = await http.Response.fromStream(streamed);
    final d = _handle(r);
    return d?.toString() ?? '';
  }

  dynamic _handle(http.Response r) {
    if (r.statusCode == 401) {
      final j = _decodeBody(r);
      final msg = j is Map ? (j['message']?.toString() ?? '未登录') : '未登录';
      throw ApiException(401, msg);
    }
    if (r.statusCode == 403) {
      throw ApiException(403, '无权限');
    }
    final j = _decodeBody(r);
    if (j is Map && j.containsKey('code')) {
      final c = (j['code'] as num).toInt();
      if (c != 0) {
        throw ApiException(c, j['message']?.toString() ?? '请求失败');
      }
      return j['data'];
    }
    if (r.statusCode >= 400) {
      throw ApiException(r.statusCode, r.reasonPhrase ?? 'HTTP错误');
    }
    return j;
  }
}
