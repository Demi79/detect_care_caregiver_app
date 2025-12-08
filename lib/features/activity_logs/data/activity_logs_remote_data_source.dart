import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'dart:convert';
import 'package:detect_care_caregiver_app/features/activity_logs/models/activity_log.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class ActivityLogsRemoteDataSource {
  final ApiClient _api;

  ActivityLogsRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<List<ActivityLog>> getUserLogs({
    required String userId,
    int? limit,
    int? offset,
    String? search,
  }) async {
    const path = '/activity-logs';

    final res = await _api.get(path, query: {'user_id': userId});

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Fetch activity logs failed: ${res.statusCode} ${res.body}',
      );
    }

    try {
      final decoded = json.decode(res.body);
      if (decoded is Map &&
          decoded.containsKey('data') &&
          decoded['data'] is List) {
        final listJson = decoded['data'];
        final jsonStr = json.encode(listJson);
        return ActivityLog.listFromJson(jsonStr);
      }

      return ActivityLog.listFromJson(res.body);
    } catch (e) {
      throw Exception('Failed to parse activity logs: $e');
    }
  }
}
