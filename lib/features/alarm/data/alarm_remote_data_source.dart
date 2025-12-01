import 'dart:convert';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:http/http.dart' as http;

class AlarmRemoteDataSource {
  /// Control endpoint as requested
  /// Control URL comes from AppConfig so it can be overridden in tests or
  /// different environments via the ALARM_CONTROL_URL environment variable.
  static String get _controlUrl => AppConfig.alarmControlUrl;

  final http.Client _client;

  AlarmRemoteDataSource({http.Client? client})
    : _client = client ?? http.Client();

  /// Send alarm control to external alarm system.
  ///
  /// payload schema:
  /// {
  ///   "event_id": "uuid",
  ///   "user_id": "uuid",
  ///   "camera_id": "uuid",
  ///   "enabled": true|false
  /// }
  Future<bool> setAlarm({
    required String eventId,
    required String userId,
    String? cameraId,
    required bool enabled,
  }) async {
    final uri = Uri.parse(_controlUrl);
    final token = await AuthStorage.getAccessToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final body = <String, dynamic>{
      'event_id': eventId,
      'user_id': userId,
      'camera_id': cameraId ?? '',
      'enabled': enabled,
    };

    try {
      AppLogger.api('→ ALARM POST $uri');
      AppLogger.api('  body=${json.encode(body)}');
      final res = await _client.post(
        uri,
        headers: headers,
        body: json.encode(body),
      );
      AppLogger.api('← ALARM POST ${res.statusCode}');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        AppLogger.api('✅ Alarm control sent successfully (${res.statusCode})');
        return true;
      }
      AppLogger.e('❌ Alarm control failed: ${res.statusCode} ${res.body}');
      throw Exception('Alarm control failed: ${res.statusCode}');
    } catch (e, st) {
      AppLogger.e('❌ Error calling alarm API: $e', e, st);
      rethrow;
    }
  }

  Future<bool> cancelAlarm({
    required String eventId,
    required String userId,
    String? cameraId,
  }) async {
    return setAlarm(
      eventId: eventId,
      userId: userId,
      cameraId: cameraId,
      enabled: false,
    );
  }
}
