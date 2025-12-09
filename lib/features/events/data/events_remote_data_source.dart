import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/analytics/analytics.dart';
import 'dart:convert' as convert;
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

class EventsRemoteDataSource {
  final ApiProvider _api;
  EventsRemoteDataSource({ApiProvider? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<List<Map<String, dynamic>>> listEvents({
    int? page,
    int? limit,
    Map<String, dynamic>? extraQuery,
  }) async {
    dev.log('\n📥 [Events] Listing events via REST /events');
    final query = <String, dynamic>{};
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;
    if (extraQuery != null) query.addAll(extraQuery);
    try {
      if (AppConfig.logHttpRequests) {
        AppLogger.api(
          '[EventsRemoteDataSource] → GET /events query=$query at=${DateTime.now().toIso8601String()}',
        );
      }
    } catch (_) {}
    final sw = Stopwatch()..start();
    AppLogger.api('[EventsRemoteDataSource] GET /events started');
    AppLogger.api('[EventsRemoteDataSource] query parameters: $query');
    final res = await _api.get('/events', query: query);
    AppLogger.api('[EventsRemoteDataSource] GET /events completed');
    AppLogger.api('[EventsRemoteDataSource] response: $res');
    sw.stop();
    try {
      if (AppConfig.logHttpRequests) {
        AppLogger.api(
          '[EventsRemoteDataSource] ← /events status=${res.statusCode} elapsed=${sw.elapsedMilliseconds}ms',
        );
        final bodyPreview = res.body.length > 2000
            ? '${res.body.substring(0, 2000)}...<truncated>'
            : res.body;
        AppLogger.api(
          '[EventsRemoteDataSource] response body preview: $bodyPreview',
        );
      }
    } catch (_) {}
    dev.log('Status: ${res.statusCode}');
    dev.log('Body: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List events failed: ${res.statusCode} ${res.body}');
    }

    final data = _api.extractDataFromResponse(res);
    if (data == null) return [];

    final decoded = _api.extractDataFromResponse(res);
    if (AppConfig.logHttpRequests) {
      AppLogger.api(
        '[EventsRemoteDataSource] decoded runtimeType=${decoded.runtimeType}',
      );
    }
    if (decoded is List) {
      if (AppConfig.logHttpRequests) {
        AppLogger.api(
          '[EventsRemoteDataSource] decoded list length=${decoded.length}',
        );
        if (decoded.isNotEmpty) {
          AppLogger.api(
            '[EventsRemoteDataSource] sample=${decoded.take(2).toList()}',
          );
        }
      }
    } else if (decoded is Map) {
      if (AppConfig.logHttpRequests) {
        AppLogger.api(
          '[EventsRemoteDataSource] decoded map keys=${decoded.keys.toList()}',
        );
        if (decoded.containsKey('data') && decoded['data'] is List) {
          AppLogger.api(
            '[EventsRemoteDataSource] decoded.data length=${(decoded['data'] as List).length}',
          );
        }
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

  Future<void> updateEvent({
    required String eventId,
    required String status,
    required String notes,
    String? eventType,
  }) async {
    AppLogger.api(
      'PATCH /events/$eventId status=$status notes=${notes.length}chars',
    );
    Analytics.logEvent('event_update_attempt', {
      'eventId': eventId,
      'status': status,
    });
    final query = {
      'status': status,
      'notes': notes,
      if (eventType != null) 'event_type': eventType,
    };
    final res = await _api.patch('/events/$eventId', query: query);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppLogger.apiError('Update event failed: ${res.statusCode} ${res.body}');
      Analytics.logEvent('event_update_failure', {
        'eventId': eventId,
        'status': status,
        'code': res.statusCode,
      });
      throw Exception('Update event failed: ${res.statusCode} ${res.body}');
    }

    AppLogger.api('Update event success: ${res.statusCode}');
    Analytics.logEvent('event_update_success', {
      'eventId': eventId,
      'status': status,
    });
  }

  Future<void> approveProposal(String eventId) async {
    final body = {'action': 'approve'};
    final res = await _api.post('/events/$eventId/confirm', body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      AppLogger.apiError(
        'Approve proposal failed: ${res.statusCode} ${res.body}',
      );
      throw Exception('Approve proposal failed: ${res.statusCode}');
    }
  }

  Future<void> rejectProposal(String eventId) async {
    final body = {'action': 'reject'};
    final res = await _api.post('/events/$eventId/reject', body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      AppLogger.apiError(
        'Reject proposal failed: ${res.statusCode} ${res.body}',
      );
      throw Exception('Reject proposal failed: ${res.statusCode}');
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
    // DEBUG: log call stack to help identify who is triggering lifecycle changes
    try {
      AppLogger.d('[EventsRemoteDataSource] updateEventLifecycle called by:');
      AppLogger.d(StackTrace.current.toString());
    } catch (_) {}
    dev.log('📤 [Events] PATCH /events/$eventId/lifecycle');

    final body = <String, dynamic>{'lifecycle_state': lifecycleState};
    if (notes != null) body['notes'] = notes;

    // LOG TẠM THỜI (Gỡ lỗi): in raw body và base URL của API để điều tra lỗi 502 / proxy.
    // Logging sẽ chỉ chạy khi AppConfig.logHttpRequests = true.
    try {
      if (AppConfig.logHttpRequests) {
        AppLogger.api(
          '[GỠ LỖI] updateEventLifecycle payload: ${convert.jsonEncode(body)}',
        );
      }
    } catch (_) {}
    try {
      // If underlying provider is ApiClient, log the base URL too.
      final apiCandidate = _api;
      if (apiCandidate is ApiClient) {
        try {
          if (AppConfig.logHttpRequests) {
            AppLogger.api('[GỠ LỖI] Base API: ${apiCandidate.base}');
          }
        } catch (_) {}
      }
    } catch (_) {}

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

  /// ================== PROPOSALS ==================

  /// Lấy danh sách proposals (pending, approved, rejected, confirmed)
  /// GET /api/events/proposals?status={status}&from={from}&to={to}&limit={limit}&cursor={cursor}
  Future<Map<String, dynamic>> listProposals({
    String status = 'all',
    String? from,
    String? to,
    int limit = 100,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      'status': status,
      'limit': '$limit',
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (cursor != null) 'cursor': cursor,
    };

    AppLogger.api('GET /api/events/proposals query=$queryParams');
    final res = await _api.get('/events/proposals', query: queryParams);

    dev.log('📥 [Eventssssss] listProposals status=${res.statusCode}');
    AppLogger.api('listProposals body length: ${res.body.length}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List proposals failed: ${res.statusCode} ${res.body}');
    }

    final decoded = convert.jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw Exception('Unexpected proposals response format: ${res.body}');
  }

  /// Lấy chi tiết proposal + history (timeline)
  /// GET /api/events/{event_id}/proposal-details
  Future<Map<String, dynamic>> getProposalDetails({
    required String eventId,
  }) async {
    dev.log('📤 [Events] GET /api/events/$eventId/proposal-details');
    final res = await _api.get('/events/$eventId/proposal-details');

    dev.log('📥 [Events] getProposalDetails status=${res.statusCode}');
    dev.log('Body: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Get proposal details failed: ${res.statusCode} ${res.body}',
      );
    }

    final decoded = convert.jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw Exception('Unexpected proposal details response format: ${res.body}');
  }

  /// Gửi đề xuất xóa sự kiện
  /// POST /api/events/{eventId}/propose-delete
  Future<Map<String, dynamic>> proposeDelete({
    required String eventId,
    required String reason,
    String? pendingUntil,
  }) async {
    AppLogger.api(
      'POST /api/events/$eventId/propose-delete reason=${reason.length}chars pendingUntil=$pendingUntil',
    );
    final body = <String, dynamic>{'reason': reason};
    if (pendingUntil != null) body['pending_until'] = pendingUntil;

    final res = await _api.post('/events/$eventId/propose-delete', body: body);
    dev.log('📤 [Events] proposeDelete status=${res.statusCode}');
    dev.log('Body: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppLogger.apiError(
        'Propose delete failed: ${res.statusCode} ${res.body}',
      );
      throw Exception('Propose delete failed: ${res.statusCode} ${res.body}');
    }

    final decoded = convert.jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('data') && decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data']);
      }
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Unexpected propose-delete response format: ${res.body}');
  }

  /// Lấy lịch sử thay đổi sự kiện (timeline)
  /// GET /api/events/{event_id}/history?expand_limit=20
  Future<List<Map<String, dynamic>>> getEventHistory({
    required String eventId,
    int expandLimit = 20,
  }) async {
    dev.log(
      '📤 [Events] GET /api/events/$eventId/history?expand_limit=$expandLimit',
    );
    final res = await _api.get(
      '/events/$eventId/history',
      query: {'expand_limit': '$expandLimit'},
    );

    dev.log('📥 [Events] getEventHistory status=${res.statusCode}');
    dev.log('Body: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Get event history failed: ${res.statusCode} ${res.body}',
      );
    }

    final decoded = convert.jsonDecode(res.body);

    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is Map && data['history'] is List) {
        return (data['history'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    throw Exception('Unexpected event history format: ${res.body}');
  }

  /// Lấy toàn bộ thông tin sự kiện, bao gồm:
  /// - Chi tiết event
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
        if (AppConfig.logHttpRequests) {
          AppLogger.api(
            '[EventsRemoteDataSource] event=$eventId discovered cloud urls:',
          );
          for (final u in found.toSet()) {
            AppLogger.api('  - $u');
          }
        }
      } else {
        if (AppConfig.logHttpRequests) {
          AppLogger.api(
            '[EventsRemoteDataSource] event=$eventId no cloud urls found in detail',
          );
        }
      }
    } catch (e) {
      try {
        AppLogger.e('[EventsRemoteDataSource] _debugPrintCloudUrls error: $e');
      } catch (_) {}
    }
  }

  /// Try to fetch a user/profile by id. Returns `null` if not available or on error.
  Future<Map<String, dynamic>?> getUserById({required String userId}) async {
    try {
      final res = await _api.get('/users/$userId');
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final decoded = convert.jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        // Common envelopes: { data: { ... } } or direct user object
        if (decoded.containsKey('data') && decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data'] as Map);
        }
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// Verify an event (APPROVED | REJECTED | CANCELED)
  /// POST /api/events/{event_id}/verify
  Future<Map<String, dynamic>> verifyEvent({
    required String eventId,
    required String action,
    String? notes,
  }) async {
    final body = <String, dynamic>{'action': action};
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

    final res = await _api.post('/events/$eventId/verify', body: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Verify event failed: ${res.statusCode} ${res.body}');
    }

    final decoded = convert.jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      // If API returns { data: { ... } }
      if (decoded.containsKey('data') && decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data']);
      }
      return decoded;
    }

    throw Exception('Unexpected verify response format: ${res.body}');
  }

  /// Escalate an event (manual escalation)
  /// POST /api/events/{event_id}/escalate
  Future<Map<String, dynamic>> escalateEvent({
    required String eventId,
    String? reason,
  }) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;

    final res = await _api.post('/events/$eventId/escalate', body: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Escalate event failed: ${res.statusCode} ${res.body}');
    }

    final decoded = convert.jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('data') && decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data']);
      }
      return decoded;
    }

    throw Exception('Unexpected escalate response format: ${res.body}');
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
}
