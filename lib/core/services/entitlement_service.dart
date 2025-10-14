import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class EntitlementService {
  final ApiProvider api;
  EntitlementService({ApiProvider? apiProvider})
    : api = apiProvider ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<bool> canAddCamera() async {
    try {
      final usage = await _fetchUsage();
      final quota = usage['camera_quota'] ?? 0;
      final used = usage['cameras_used'] ?? 0;
      return used < quota;
    } catch (e) {
      return false;
    }
  }

  Future<bool> canAddSite() async {
    try {
      final usage = await _fetchUsage();
      final quota = usage['sites'] ?? 0;
      final used = usage['sites_used'] ?? 0;
      return used < quota;
    } catch (e) {
      return false;
    }
  }

  Future<bool> canAddCaregiverSeat() async {
    try {
      final usage = await _fetchUsage();
      final quota = usage['caregiver_seats'] ?? 0;
      final used = usage['seats_used'] ?? 0;
      return used < quota;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getStorageUsage() async {
    try {
      final usage = await _fetchUsage();
      return {
        'used_gb': usage['storage_used_gb'] ?? 0.0,
        'quota_gb': usage['storage_size_gb'] ?? 0.0,
        'is_over':
            (usage['storage_used_gb'] ?? 0.0) >
            (usage['storage_size_gb'] ?? 0.0),
      };
    } catch (e) {
      return {'used_gb': 0.0, 'quota_gb': 0.0, 'is_over': false};
    }
  }

  Future<Map<String, dynamic>> _fetchUsage() async {
    final res = await api.get('/dashboard/plan-usage');
    final data = api.extractDataFromResponse(res);
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw Exception('Invalid usage data');
  }
}
