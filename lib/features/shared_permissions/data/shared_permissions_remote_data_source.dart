import 'dart:convert';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/models/shared_permissions.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/data/shared_permissions_endpoints.dart';
import 'package:flutter/foundation.dart';

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
    final endpoint = '/caregivers/$caregiverId/shared-permissions';
    final res = await _api.get(endpoint);

    try {
      print('[HTTP] GET $endpoint => ${res.statusCode}');
      print(res.body);
    } catch (_) {}

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

  Future<Map<String, dynamic>> createPermissionRequest({
    required String customerId,
    required String caregiverId,
    required String type,
    required bool requestedBool,
    required String scope,
    required String reason,
  }) async {
    final body = {
      "customerId": customerId,
      "caregiverId": caregiverId,
      "type": type,
      "requested_bool": requestedBool,
      "scope": scope,
      "reason": reason,
    };

    try {
      final res = await _api.post('/permission-requests', body: body);

      if (res.statusCode != 201) {
        debugPrint(
          'POST /permission-requests failed: status=${res.statusCode}',
        );
        debugPrint('  body=${res.body}');
        try {
          debugPrint('  headers=${res.headers}');
        } catch (_) {}

        try {
          final parsed = json.decode(res.body);
          if (parsed is Map) {
            if (parsed['error'] is Map && parsed['error']['message'] != null) {
              final serverMsg = parsed['error']['message'].toString();
              throw Exception(serverMsg);
            }

            if (parsed['message'] != null) {
              throw Exception(parsed['message'].toString());
            }
          }
        } catch (_) {
          // ignore parse errors
        }

        throw Exception(
          'POST /permission-requests failed: ${res.statusCode} ${res.body}',
        );
      }

      final decoded = json.decode(res.body) as Map<String, dynamic>;
      return decoded;
    } catch (e, st) {
      debugPrint('createPermissionRequest error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestDaysPermission({
    required String customerId,
    required String caregiverId,
    required String type, // log_access_days hoặc report_access_days
    required int requestedDays,
    required String reason,
  }) async {
    final body = {
      "customerId": customerId,
      "caregiverId": caregiverId,
      "type": type,
      "requested_days": requestedDays,
      "reason": reason,
    };

    final res = await _api.post('/permission-requests', body: body);

    if (res.statusCode != 201) {
      try {
        final parsed = json.decode(res.body);
        if (parsed is Map) {
          if (parsed['error'] is Map && parsed['error']['message'] != null) {
            throw Exception(parsed['error']['message'].toString());
          }
          if (parsed['message'] != null) {
            throw Exception(parsed['message'].toString());
          }
        }
      } catch (_) {
        // ignore parse errors
      }

      throw Exception(
        'POST /permission-requests failed: ${res.statusCode} ${res.body}',
      );
    }

    return json.decode(res.body) as Map<String, dynamic>;
  }
}
