import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:detect_care_caregiver_app/features/fcm/data/fcm_remote_data_source.dart';

class FcmRegistration {
  final FcmRemoteDataSource ds;
  StreamSubscription<String>? _sub;
  String _lastUserId = '';

  FcmRegistration(this.ds);
  Future<void> registerForUser(String userId, {String type = 'device'}) async {
    if (userId.isEmpty || _lastUserId == userId) return;
    _lastUserId = userId;

    try {
      final permissions = await FirebaseMessaging.instance.requestPermission();
      if (permissions.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('❌ [FCM] No permission granted for notifications');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('❌ [FCM] Failed to get FCM token');
        return;
      }

      await ds.saveToken(userId: userId, token: token, type: type);
      debugPrint('✅ [FCM] Successfully registered token for user $userId');
    } catch (e) {
      debugPrint('❌ [FCM] Error registering device: $e');
      rethrow;
    }

    await _sub?.cancel();
    _sub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      ds.saveToken(userId: userId, token: newToken, type: type);
    });
  }

  Future<String?> getCurrentTokenSafely() async {
    try {
      final t = await FirebaseMessaging.instance.getToken();
      return (t != null && t.isNotEmpty) ? t : null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
