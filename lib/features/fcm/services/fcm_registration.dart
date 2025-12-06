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

    // Debug log the user ID format
    debugPrint('🔍 [FcmRegistration] Registering FCM for userId: "$userId"');
    debugPrint('🔍 [FcmRegistration] userId length: ${userId.length}');
    debugPrint(
      '🔍 [FcmRegistration] userId contains dashes: ${userId.contains('-')}',
    );

    // Basic UUID validation
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    final isValidUuid = uuidRegex.hasMatch(userId);
    debugPrint('🔍 [FcmRegistration] Is valid UUID format: $isValidUuid');

    if (!isValidUuid) {
      debugPrint(
        '❌ [FcmRegistration] userId is not a proper UUID format, but proceeding anyway: $userId',
      );
    }

    _lastUserId = userId;

    await FirebaseMessaging.instance.requestPermission();

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await ds.saveToken(userId: userId, token: token, type: type);
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
