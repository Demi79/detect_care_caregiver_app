import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/core/config/app_config.dart';

typedef TokenProvider = Future<String?> Function();

class ApiClient {
  final http.Client _client;
  final TokenProvider? _tokenProvider;
  final String base;

  ApiClient({http.Client? client, TokenProvider? tokenProvider})
    : _client = client ?? http.Client(),
      _tokenProvider = tokenProvider,
      base = AppConfig.apiBaseUrl;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');
    if (query == null || query.isEmpty) return uri;
    final qp = <String, String>{};
    query.forEach((k, v) {
      if (v == null) return;
      if (v is List) {
        qp[k] = v.join(',');
      } else {
        qp[k] = v.toString();
      }
    });
    return uri.replace(queryParameters: qp);
  }

  Future<Map<String, String>> _headers([Map<String, String>? extra]) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  void _logRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) {
    if (!AppConfig.logHttpRequests) return;
    final maskedHeaders = Map<String, String>.from(headers);
    if (maskedHeaders.containsKey('Authorization')) {
      final auth = maskedHeaders['Authorization']!;
      maskedHeaders['Authorization'] = auth.length > 16
          ? '${auth.substring(0, 16)}…(masked)'
          : '(masked)';
    }
    Object? maskedBody = body;
    try {
      if (body is String) {
        final jsonBody = json.decode(body);
        if (jsonBody is Map) {
          final copy = Map<String, dynamic>.from(jsonBody);
          if (copy.containsKey('otp_code')) copy['otp_code'] = '***';
          if (copy.containsKey('password')) copy['password'] = '***';
          maskedBody = json.encode(copy);
        }
      }
    } catch (_) {}
    debugPrint('[HTTP] → $method ${uri.toString()}');
    debugPrint('  headers=${json.encode(maskedHeaders)}');
    if (maskedBody != null && maskedBody.toString().isNotEmpty) {
      debugPrint('  body=$maskedBody');
    }
  }

  void _logResponse(String method, Uri uri, http.Response res, Duration dt) {
    if (!AppConfig.logHttpRequests) return;
    debugPrint(
      '[HTTP] ← $method ${uri.toString()} (${res.statusCode}) in ${dt.inMilliseconds}ms',
    );
  }

  Future<http.Response> get(String path, {Map<String, dynamic>? query}) async {
    final uri = _uri(path, query);
    final headers = await _headers();
    final sw = Stopwatch()..start();
    _logRequest('GET', uri, headers, null);
    final res = await _client.get(uri, headers: headers);
    sw.stop();
    _logResponse('GET', uri, res, sw.elapsed);
    return res;
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path, query);
    final headers = await _headers();
    final encodedBody = body == null ? null : json.encode(body);
    final sw = Stopwatch()..start();
    _logRequest('POST', uri, headers, encodedBody);
    final res = await _client.post(uri, headers: headers, body: encodedBody);
    sw.stop();
    _logResponse('POST', uri, res, sw.elapsed);
    return res;
  }

  Future<http.Response> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path, query);
    final headers = await _headers();
    final encodedBody = body == null ? null : json.encode(body);
    final sw = Stopwatch()..start();
    _logRequest('PUT', uri, headers, encodedBody);
    final res = await _client.put(uri, headers: headers, body: encodedBody);
    sw.stop();
    _logResponse('PUT', uri, res, sw.elapsed);
    return res;
  }

  Future<http.Response> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path, query);
    final headers = await _headers();
    final encodedBody = body == null ? null : json.encode(body);
    final sw = Stopwatch()..start();
    _logRequest('PATCH', uri, headers, encodedBody);
    final res = await _client.patch(uri, headers: headers, body: encodedBody);
    sw.stop();
    _logResponse('PATCH', uri, res, sw.elapsed);
    return res;
  }

  Future<http.Response> delete(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path, query);
    final headers = await _headers();
    final sw = Stopwatch()..start();
    _logRequest('DELETE', uri, headers, null);
    final res = await _client.delete(uri, headers: headers);
    sw.stop();
    _logResponse('DELETE', uri, res, sw.elapsed);
    return res;
  }
}
