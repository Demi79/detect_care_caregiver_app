import 'dart:convert';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import '../models/settings_models.dart';
import 'settings_endpoints.dart';

class SettingsRemoteDataSource {
  final ApiClient client;
  final SettingsEndpoints endpoints;
  SettingsRemoteDataSource({ApiClient? client, required this.endpoints})
    : client = client ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<AppSettings> fetchSettings() async {
    final res = await client
        .get('/settings')
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Fetch settings failed: ${res.statusCode} ${res.body}');
    }
    final map = json.decode(res.body) as Map<String, dynamic>;
    final payload = (map['data'] is Map)
        ? (map['data'] as Map).cast<String, dynamic>()
        : map;
    return AppSettings.fromJson(payload);
  }

  Future<AppSettings> updateSettings(
    String key,
    AppSettings settings, {
    bool patch = true,
  }) async {
    final body = settings.toJson();
    final res = patch
        ? await client.patch('/settings/$key', body: body)
        : await client.put('/settings/$key', body: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update settings failed: ${res.statusCode} ${res.body}');
    }
    final map = json.decode(res.body) as Map<String, dynamic>;
    final payload = (map['data'] is Map)
        ? (map['data'] as Map).cast<String, dynamic>()
        : map;
    return AppSettings.fromJson(payload);
  }
}
