import 'dart:async';
import 'dart:convert';

import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class PushService {
  static final PushService instance = PushService._();
  PushService._();

  static const _maxAttempts = 5;
  static const _baseDelayMs = 500;

  Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  static Future<void> registerDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('FCM token is null');
        return;
      }

      final base = AppConfig.apiBaseUrl;
      final normalizedBase = base.endsWith('/')
          ? base.substring(0, base.length - 1)
          : base;
      final hasApiSegment = normalizedBase
          .split('/')
          .where((s) => s.isNotEmpty)
          .contains('api');
      final uri = Uri.parse(
        '$normalizedBase${hasApiSegment ? '' : '/api'}/v1/register-fcm-token',
      );

      int attempt = 0;
      while (attempt < _maxAttempts) {
        try {
          final res = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'token': token}),
          );
          if (res.statusCode >= 200 && res.statusCode < 300) {
            debugPrint('FCM token registered successfully');
            return;
          } else {
            debugPrint('Registration failed ${res.statusCode}: ${res.body}');
            throw Exception('Bad status');
          }
        } catch (e) {
          attempt++;
          final delay = _baseDelayMs * (1 << (attempt - 1));
          debugPrint(
            'Retrying registerDeviceToken in ${delay}ms (attempt $attempt) due to $e',
          );
          await Future.delayed(Duration(milliseconds: delay));
        }
      }
      debugPrint('Failed to register FCM token after $_maxAttempts attempts');
    } catch (e) {
      debugPrint('Exception in registerDeviceToken: $e');
    }
  }
}
