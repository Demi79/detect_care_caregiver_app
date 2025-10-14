import 'dart:convert';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/models/shared_permissions.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/data/shared_permissions_endpoints.dart';

class SharedPermissionsRemoteDataSource {
  final ApiClient _api;
  final SharedPermissionsEndpoints endpoints;

  SharedPermissionsRemoteDataSource({
    ApiClient? api,
    SharedPermissionsEndpoints? endpoints,
  }) : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken),
       endpoints = endpoints ?? makeSharedPermissionsEndpoints();

  Future<SharedPermissions> getSharedPermissions({
    required String customerId,
    required String caregiverId,
  }) async {
    final res = await _api.get(endpoints.pair(customerId, caregiverId));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'GET shared-permissions failed: ${res.statusCode} ${res.body}',
      );
    }
    return SharedPermissions.fromJson(
      json.decode(res.body) as Map<String, dynamic>,
    );
  }

  Future<List<SharedPermissions>> getByCaregiverId(String caregiverId) async {
    final res = await _api.get('/caregivers/$caregiverId/shared-permissions');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Failed to fetch shared permissions: ${res.statusCode} ${res.body}',
      );
    }

    final decoded = json.decode(res.body);

    List items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map && decoded['data'] is List) {
      items = decoded['data'] as List;
    } else {
      throw Exception('Unexpected response format: ${res.body}');
    }

    return items
        .map(
          (e) => SharedPermissions.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }
}
