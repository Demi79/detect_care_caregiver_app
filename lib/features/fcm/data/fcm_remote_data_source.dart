import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/fcm/data/fcm_endpoints.dart';

class FcmRemoteDataSource {
  final ApiClient? _api;
  final http.Client? _client;
  final FcmEndpoints endpoints;

  FcmRemoteDataSource({
    ApiClient? api,
    http.Client? client,
    required this.endpoints,
  }) : _api = api,
       _client = client;

  Future<void> saveToken({
    required String userId,
    required String token,
    String type = 'device',
  }) async {
    final payload = {'userId': userId, 'token': token, 'type': type};

    if (_api != null) {
      final res = await _api.post(endpoints.postTokenPath, body: payload);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Save FCM token failed: ${res.statusCode} ${res.body}');
      }
      return;
    }

    if (_client == null) {
      throw StateError(
        'No ApiClient or http.Client provided for FcmRemoteDataSource',
      );
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    final access = await AuthStorage.getAccessToken();
    if (access != null && access.isNotEmpty) {
      headers['Authorization'] = 'Bearer $access';
    }

    final res = await _client.post(
      endpoints.postTokenUri,
      headers: headers,
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Save FCM token failed: ${res.statusCode} ${res.body}');
    }
  }

  bool _isUuid(String s) {
    final r = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return r.hasMatch(s);
  }

  Future<Map<String, dynamic>> pushMessage({
    required List<String> toUserIds,
    required String direction,
    required String category,
    required String message,
    required String fromUserId,
    String? deeplink,
  }) async {
    if (toUserIds.isEmpty) {
      throw ArgumentError('toUserIds không được rỗng');
    }
    if (!_isUuid(fromUserId)) {
      throw ArgumentError('fromUserId phải là UUID');
    }

    for (final id in toUserIds) {
      if (!_isUuid(id)) {
        throw ArgumentError('Invalid user ID format: $id');
      }
    }

    final payload = <String, dynamic>{
      'toUserIds': toUserIds,
      'direction': direction,
      'category': category,
      'message': message,
      'fromUserId': fromUserId,
      if (deeplink != null && deeplink.isNotEmpty) 'deeplink': deeplink,
    };

    dev.log('\n📤 [FCM] Sending push message:');
    dev.log('URL: ${endpoints.postMessageUri}');
    dev.log('Payload:');
    dev.log(const JsonEncoder.withIndent('  ').convert(payload));

    if (_api != null) {
      final res = await _api.post(endpoints.postMessagePath, body: payload);

      dev.log('\n📥 [FCM] Push response:');
      dev.log('Status: ${res.statusCode}');
      dev.log('Body: ${res.body}');

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Push FCM thất bại: ${res.statusCode} ${res.body}');
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    if (_client == null) {
      throw StateError('No ApiClient or http.Client available for pushMessage');
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    final access = await AuthStorage.getAccessToken();
    if (access != null && access.isNotEmpty) {
      headers['Authorization'] = 'Bearer $access';
    }

    final res = await _client.post(
      endpoints.postMessageUri,
      headers: headers,
      body: jsonEncode(payload),
    );

    dev.log('\n📥 [FCM] Push response:');
    dev.log('Status: ${res.statusCode}');
    dev.log('Body: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Push FCM thất bại: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
