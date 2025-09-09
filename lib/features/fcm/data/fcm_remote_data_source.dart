import 'dart:convert';
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
      final res = await _api!.post(endpoints.postTokenPath, body: payload);
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

    final res = await _client!.post(
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

    final payload = <String, dynamic>{
      'message': {
        'token': toUserIds.first,
        'notification': {
          'title': category == 'help' ? '🆘 Help Request' : 'New Message',
          'body': message,
        },
        'data': {
          'type': 'actor_message',
          'direction': direction,
          'category': category,
          'message': message,
          'fromUserId': fromUserId,
          if (deeplink != null && deeplink.isNotEmpty) 'deeplink': deeplink,
        },
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': 'healthcare_alerts',
            'priority': 'high',
            'default_sound': true,
            'default_vibrate_timings': true,
          },
        },
        'apns': {
          'headers': {'apns-priority': '10'},
          'payload': {
            'aps': {'sound': 'default', 'badge': 1, 'content-available': 1},
          },
        },
      },
      'validate_only': false,
    };

    print('\n📤 [FCM] Sending push message:');
    print('URL: ${endpoints.postMessageUri}');
    print('Payload:');
    print(JsonEncoder.withIndent('  ').convert(payload));

    if (_api != null) {
      final res = await _api!.post(endpoints.postMessagePath, body: payload);

      print('\n📥 [FCM] Push response:');
      print('Status: ${res.statusCode}');
      print('Body: ${res.body}');

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

    final res = await _client!.post(
      endpoints.postMessageUri,
      headers: headers,
      body: jsonEncode(payload),
    );

    print('\n📥 [FCM] Push response:');
    print('Status: ${res.statusCode}');
    print('Body: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Push FCM thất bại: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
