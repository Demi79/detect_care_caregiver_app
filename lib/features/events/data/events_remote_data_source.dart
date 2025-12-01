import 'dart:developer' as dev;
import 'dart:convert' as convert;
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:http/http.dart' as http;
// import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

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
    int limit = 100,
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
      if (decoded.isNotEmpty) {
        print('[EventsRemoteDataSource] sample=${decoded.take(2).toList()}');
      }
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
            return (v)
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

  Future<Map<String, dynamic>> getEventById({required String eventId}) async {
    final res = await _api.get('/events/$eventId');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Get event by id failed: ${res.statusCode} ${res.body}');
    }

    final decoded = convert.jsonDecode(res.body);
    if (decoded is Map && decoded['data'] is Map<String, dynamic>) {
      try {
        final detail = Map<String, dynamic>.from(decoded['data'] as Map);
        _debugPrintCloudUrls(detail, eventId);
      } catch (_) {}
      return Map<String, dynamic>.from(decoded['data']);
    }
    throw Exception('Unexpected /events/{id} response format: ${res.body}');
  }

  void _debugPrintCloudUrls(Map<String, dynamic> detail, String eventId) {
    try {
      final found = <String>[];

      void takeValue(dynamic v) {
        if (v is String && v.isNotEmpty) {
          final s = v.trim();
          if (s.startsWith('http://') || s.startsWith('https://')) {
            found.add(s);
          }
        }
      }

      void scan(dynamic node) {
        if (node == null) return;
        if (node is String) return takeValue(node);
        if (node is Map) {
          for (final entry in node.entries) {
            final k = entry.key?.toString().toLowerCase() ?? '';
            final v = entry.value;
            if (k.contains('cloud') ||
                k.contains('snapshot') ||
                k.contains('url')) {
              if (v is String) takeValue(v);
              if (v is List) v.forEach(takeValue);
            }
            scan(v);
          }
          return;
        }
        if (node is List) {
          for (final e in node) {
            scan(e);
          }
          return;
        }
      }

      scan(detail);
      if (found.isNotEmpty) {
        print('[EventsRemoteDataSource] event=$eventId discovered cloud urls:');
        for (final u in found.toSet()) {
          print('  - $u');
        }
      } else {
        print(
          '[EventsRemoteDataSource] event=$eventId no cloud urls found in detail',
        );
      }
    } catch (e) {
      try {
        print('[EventsRemoteDataSource] _debugPrintCloudUrls error: $e');
      } catch (_) {}
    }
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

  Future<Map<String, dynamic>> createManualAlert({
    required String cameraId,
    required String imagePath,
    String? notes,
    Map<String, dynamic>? contextData,
  }) async {
    final fields = {
      "camera_id": cameraId,
      "event_type": "emergency",
      "status": "danger",
      "notes": notes ?? "Manual alarm triggered",
      "context_data": convert.jsonEncode(
        contextData ?? {"source": "manual_button"},
      ),
    };

    final file = await http.MultipartFile.fromPath("image_files", imagePath);

    final res = await _api.postMultipart(
      "/events/alarm",
      fields: fields,
      files: [file],
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        "Create manual alert failed: ${res.statusCode} ${res.body}",
      );
    }

    final decoded = convert.jsonDecode(res.body);
    if (decoded is Map && decoded["data"] is Map) {
      return Map<String, dynamic>.from(decoded["data"]);
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// Cập nhật lifecycle cho event
  /// PATCH /api/events/{event_id}/lifecycle
  /// body: { "lifecycle_state": "ALARM_ACTIVATED", "notes": "..." }
  Future<void> updateEventLifecycle({
    required String eventId,
    required String lifecycleState,
    String? notes,
  }) async {
    AppLogger.api(
      'PATCH /events/$eventId/lifecycle lifecycle_state=$lifecycleState notes=${notes?.length ?? 0}',
    );
    dev.log('📤 [Events] PATCH /events/$eventId/lifecycle');

    final body = <String, dynamic>{'lifecycle_state': lifecycleState};
    if (notes != null) body['notes'] = notes;

    final res = await _api.patch('/events/$eventId/lifecycle', body: body);
    dev.log('📥 [Events] updateEventLifecycle status=${res.statusCode}');
    dev.log('Body: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppLogger.apiError(
        'Update lifecycle failed: ${res.statusCode} ${res.body}',
      );
      throw Exception('Update lifecycle failed: ${res.statusCode} ${res.body}');
    }

    AppLogger.api('Update lifecycle success: ${res.statusCode}');
  }

  /// Cancel an event by setting lifecycle_state = CANCELED
  /// PATCH /api/events/{eventId}/cancel with body { reason: ... }
  Future<void> cancelEvent({
    required String eventId,
    String reason = 'Sự kiện không chính xác',
  }) async {
    AppLogger.api('PATCH /events/$eventId/cancel reason=${reason.length}chars');
    final body = {'reason': reason};
    final res = await _api.patch('/events/$eventId/cancel', body: body);
    dev.log('📤 [Events] cancelEvent status=${res.statusCode}');
    dev.log('Body: ${res.body}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppLogger.apiError('Cancel event failed: ${res.statusCode} ${res.body}');
      throw Exception('Cancel event failed: ${res.statusCode} ${res.body}');
    }
    AppLogger.api('Cancel event success: ${res.statusCode}');
  }
}
