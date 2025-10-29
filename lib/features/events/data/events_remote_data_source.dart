import 'dart:developer' as dev;
import 'dart:convert' as convert;
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
// import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';

class EventsRemoteDataSource {
  final ApiClient _api;
  EventsRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<void> updateEvent({
    required String eventId,
    required String status,
    required String notes,
  }) async {
    final body = {'status': status, 'notes': notes};
    print('\n📤 [Events] Update event payload: ${body.toString()}');

    final res = await _api.patch('/events/$eventId', body: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      String serverMsg = res.body;
      try {
        final decoded = convert.jsonDecode(res.body);
        if (decoded is Map) {
          if (decoded.containsKey('error') &&
              decoded['error'] is Map &&
              decoded['error']['message'] != null) {
            serverMsg = decoded['error']['message'].toString();
          } else if (decoded['message'] != null) {
            serverMsg = decoded['message'].toString();
          } else {
            serverMsg = convert.jsonEncode(decoded);
          }
        }
      } catch (_) {}

      throw Exception('Update event failed: ${res.statusCode} $serverMsg');
    }
  }

  Future<List<Map<String, dynamic>>> listEvents({
    int page = 1,
    int limit = 50,
    Map<String, dynamic>? extraQuery,
  }) async {
    dev.log(
      '\n📥 [Events] Listing events via REST /events (page=$page limit=$limit)',
    );
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (extraQuery != null) query.addAll(extraQuery);
    final res = await _api.get('/events', query: query);
    dev.log('Status: ${res.statusCode}');
    dev.log('Body: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List events failed: ${res.statusCode} ${res.body}');
    }

    final data = _api.extractDataFromResponse(res);
    if (data == null) return [];

    final decoded = _api.extractDataFromResponse(res);
    print(
      '[EventsRemoteDataSource] decoded runtimeType=${decoded.runtimeType}',
    );
    if (decoded is List) {
      print('[EventsRemoteDataSource] decoded list length=${decoded.length}');
      if (decoded.isNotEmpty)
        print('[EventsRemoteDataSource] sample=${decoded.take(2).toList()}');
    } else if (decoded is Map) {
      print(
        '[EventsRemoteDataSource] decoded map keys=${decoded.keys.toList()}',
      );
      if (decoded.containsKey('data') && decoded['data'] is List) {
        print(
          '[EventsRemoteDataSource] decoded.data length=${(decoded['data'] as List).length}',
        );
      }
    }
    if (data is List) {
      return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }

    if (data is Map<String, dynamic>) {
      // direct `data` key with list
      if (data.containsKey('data') && data['data'] is List) {
        return (data['data'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }

      // common alternate envelopes
      if (data.containsKey('events') && data['events'] is List) {
        return (data['events'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }

      if (data.containsKey('rows') && data['rows'] is List) {
        return (data['rows'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }

      if (data.containsKey('items') && data['items'] is List) {
        return (data['items'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }

      // Sometimes extractDataFromResponse already returned the inner map
      // which itself contains a `data`/`events` list.
      for (final v in data.values) {
        if (v is List) {
          try {
            return (v as List)
                .map<Map<String, dynamic>>(
                  (e) => Map<String, dynamic>.from(e as Map),
                )
                .toList();
          } catch (_) {
            // ignore and continue
          }
        }
      }
    }

    throw Exception(
      'Unexpected events list response shape: ${data.runtimeType}',
    );
  }

  Future<void> confirmEvent({
    required String eventId,
    bool? confirm,
    String? confirmStatus,
    bool? confirmStatusBool,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (confirm != null) body['confirm'] = confirm;
    if (confirmStatus != null) body['confirm_status'] = confirmStatus;
    if (confirmStatusBool != null) body['confirm_status'] = confirmStatusBool;
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

    final res = await _api.patch(
      '/event-detections/$eventId/confirm-status',
      body: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      String serverMsg = res.body;
      try {
        final decoded = convert.jsonDecode(res.body);
        if (decoded is Map) {
          if (decoded.containsKey('error') &&
              decoded['error'] is Map &&
              decoded['error']['message'] != null) {
            serverMsg = decoded['error']['message'].toString();
          } else if (decoded['message'] != null) {
            serverMsg = decoded['message'].toString();
          } else {
            serverMsg = convert.jsonEncode(decoded);
          }
        }
      } catch (_) {}

      throw Exception('Confirm event failed: ${res.statusCode} $serverMsg');
    }
  }
}
