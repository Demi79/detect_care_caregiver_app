import 'dart:convert';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/profile/model/user_profile.dart';

class UsersRemoteDataSource {
  final ApiClient api;

  UsersRemoteDataSource(this.api);

  Future<UserProfile> getUser(String userId) async {
    final res = await api.get('/users/$userId');

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = api.extractDataFromResponse(res);
      return UserProfile.fromJson(data);
    }

    throw Exception('Failed to load user profile');
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> body) async {
    final res = await api.put('/users/$userId', body: body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return true;
    }

    String details = res.body;
    try {
      final parsed = jsonDecode(res.body);
      if (parsed is Map && parsed['message'] != null) {
        details = parsed['message'].toString();
      } else if (parsed is Map && parsed['errors'] != null) {
        details = jsonEncode(parsed['errors']);
      }
    } catch (_) {
      // ignore parse errors and keep raw body
    }

    throw Exception(
      'Failed to update user (status=${res.statusCode}): $details',
    );
  }
}
