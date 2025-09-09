import 'dart:convert';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/models/user.dart';

class CaregiversRemoteDataSource {
  final ApiClient _api;
  CaregiversRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<List<User>> search({required String keyword, int? limit}) async {
    final res = await _api.get(
      '/caregivers/search',
      query: {'keyword': keyword, if (limit != null) 'limit': limit},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Search caregivers failed: ${res.statusCode} ${res.body}',
      );
    }

    final decoded = json.decode(res.body);

    final List list = (decoded is Map && decoded['data'] is List)
        ? decoded['data'] as List
        : decoded as List;

    return list.map<User>((e) {
      final m = (e as Map).cast<String, dynamic>();
      return User(
        id: (m['user_id'] ?? m['id'] ?? '').toString(),
        username: m['username']?.toString() ?? '',
        fullName: m['full_name']?.toString() ?? '',
        email: m['email']?.toString() ?? '',
        role: m['role']?.toString() ?? '',
        phone: (m['phone_number'] ?? m['phone'] ?? '').toString(),
        isFirstLogin: m['is_first_login'] == true,
        avatarUrl: m['avatar_url']?.toString(),
      );
    }).toList();
  }
}
