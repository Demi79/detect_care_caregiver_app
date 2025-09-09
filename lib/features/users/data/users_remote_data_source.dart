import 'dart:convert';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/models/user.dart';

class UsersRemoteDataSource {
  final ApiClient _api;
  UsersRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<List<User>> listUsers({
    String? role,
    String? search,
    int? page,
    int? limit,
  }) async {
    final res = await _api.get(
      '/users',
      query: {
        if (role != null && role.isNotEmpty) 'role': role,
        if (search != null && search.isNotEmpty) 'search': search,
        if (page != null) 'page': page,
        if (limit != null) 'limit': limit,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('List users failed: ${res.statusCode} ${res.body}');
    }
    final body = json.decode(res.body);
    final List dataList = body is Map && body['data'] is List
        ? body['data'] as List
        : (body as List);
    return dataList
        .whereType<Map>()
        .map((e) => User.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
