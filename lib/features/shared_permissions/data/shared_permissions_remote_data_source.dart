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
          final decoded = json.decode(res.body);
          if (decoded is Map) {
            if (decoded['error'] is Map &&
                decoded['error']['message'] != null) {
              final serverMsg = decoded['error']['message'].toString();
              throw Exception(serverMsg);
            }

            if (decoded['message'] != null) {
              throw Exception(decoded['message'].toString());
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

  /// Backwards-compatible alias for older callers.
  /// Returns null if the remote call fails for any reason.
  Future<SharedPermissions?> getPermission({
    required String customerId,
    required String caregiverId,
  }) async {
    try {
      return await getSharedPermissions(
        customerId: customerId,
        caregiverId: caregiverId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Update shared permissions for a customer-caregiver pair.
  /// Returns a lightweight result containing caregiver info and the saved permissions.
  Future<UpdatePermissionsResult> updatePermissions({
    required String customerId,
    required String caregiverId,
    required SharedPermissions permissions,
    String? caregiverUsername,
    String? caregiverPhone,
    String? caregiverFullName,
  }) async {
    final endpoint = endpoints.pair(customerId, caregiverId);
    final body = <String, dynamic>{};
    body.addAll(permissions.toJson());
    if (caregiverUsername != null && caregiverUsername.isNotEmpty) {
      body['caregiver_username'] = caregiverUsername;
    }
    if (caregiverPhone != null && caregiverPhone.isNotEmpty) {
      body['caregiver_phone'] = caregiverPhone;
    }
    if (caregiverFullName != null && caregiverFullName.isNotEmpty) {
      body['caregiver_full_name'] = caregiverFullName;
    }
    final res = await _api.put(endpoint, body: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Update permissions failed: ${res.statusCode} ${res.body}',
      );
    }

    try {
      final decoded = json.decode(res.body) as Map<String, dynamic>;
      final caregiverFullName =
          decoded['caregiver_full_name']?.toString() ??
          decoded['caregiverFullName']?.toString() ??
          '';
      final caregiverPhone =
          decoded['caregiver_phone']?.toString() ??
          decoded['caregiverPhone']?.toString() ??
          '';
      final perms = decoded['permissions'] is Map
          ? SharedPermissions.fromJson(
              (decoded['permissions'] as Map).cast<String, dynamic>(),
            )
          : permissions;
      return UpdatePermissionsResult(
        caregiverFullName: caregiverFullName,
        caregiverPhone: caregiverPhone,
        permissions: perms,
      );
    } catch (_) {
      return UpdatePermissionsResult(
        caregiverFullName: '',
        caregiverPhone: '',
        permissions: permissions,
      );
    }
  }
}

class UpdatePermissionsResult {
  final String caregiverFullName;
  final String caregiverPhone;
  final SharedPermissions permissions;

  UpdatePermissionsResult({
    required this.caregiverFullName,
    required this.caregiverPhone,
    required this.permissions,
  });
}
