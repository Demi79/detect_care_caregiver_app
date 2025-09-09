import 'dart:convert';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class MePreferencesRemoteDataSource {
  final ApiClient _api;
  MePreferencesRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<Map<String, dynamic>?> getAppearance() async {
    final res = await _api.get('/me/preferences/appearance');
    if (res.statusCode != 200) return null;
    return (json.decode(res.body) as Map).cast<String, dynamic>();
  }

  Future<void> setAppearance({
    required String theme,
    required String font,
  }) async {
    final res = await _api.put(
      '/me/preferences/appearance',
      body: {'theme': theme, 'font': font},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Set appearance failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<Map<String, dynamic>?> getNotifications() async {
    final res = await _api.get('/me/preferences/notifications');
    if (res.statusCode != 200) return null;
    return (json.decode(res.body) as Map).cast<String, dynamic>();
  }

  Future<void> setNotifications({
    required String type,
    required bool mobile,
    required bool communicationEmails,
    required bool socialEmails,
    required bool marketingEmails,
    required bool securityEmails,
  }) async {
    final res = await _api.put(
      '/me/preferences/notifications',
      body: {
        'type': type,
        'mobile': mobile,
        'communication_emails': communicationEmails,
        'social_emails': socialEmails,
        'marketing_emails': marketingEmails,
        'security_emails': securityEmails,
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Set notifications failed: ${res.statusCode} ${res.body}',
      );
    }
  }

  Future<Map<String, dynamic>?> getDisplay() async {
    final res = await _api.get('/me/preferences/display');
    if (res.statusCode != 200) return null;
    return (json.decode(res.body) as Map).cast<String, dynamic>();
  }

  Future<void> setDisplay({required List<String> items}) async {
    final res = await _api.put(
      '/me/preferences/display',
      body: {'items': items},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Set display failed: ${res.statusCode} ${res.body}');
    }
  }
}
