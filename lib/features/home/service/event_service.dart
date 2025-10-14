import 'dart:convert' as convert;
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/home/data/event_endpoints.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';

import '../models/event_log.dart';

class EventService {
  final _supabase = Supabase.instance.client;
  final ApiClient _api;

  EventService.withDefaultClient()
    : _api = ApiClient(tokenProvider: AuthStorage.getAccessToken);

  EventService(this._api);

  void debugProbe() {
    final session = _supabase.auth.currentSession;
    dev.log(
      'EventService probe:'
      '\n- hasSession: ${session != null}'
      '\n- userId: ${session?.user.id}'
      '\n- expired: ${session?.isExpired}',
      name: 'EventService',
    );
  }

  Future<List<EventLog>> fetchLogs({
    int page = 1,
    int limit = 50,
    String? status,
    DateTimeRange? dayRange,
    String? period,
    String? search,
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        dev.log('No Supabase session found', name: 'EventService.fetchLogs');
        return [];
      }

      dev.log(
        'filters status=$status, dayRange=${dayRange != null ? "${dayRange.start}..${dayRange.end}" : "null"}, period=$period, search=$search, page=$page, limit=$limit',
        name: 'EventService.fetchLogs',
      );

      var query = _supabase
          .from(EventEndpoints.eventsTable)
          .select(EventEndpoints.selectList);

      if (status != null && status.isNotEmpty && status != 'All') {
        query = query.eq(EventEndpoints.status, status);
      }

      if (dayRange != null) {
        final startUtc = DateTime(
          dayRange.start.year,
          dayRange.start.month,
          dayRange.start.day,
        ).toUtc();
        final endUtc = DateTime(
          dayRange.end.year,
          dayRange.end.month,
          dayRange.end.day + 1,
        ).toUtc();

        query = query
            .gte(EventEndpoints.detectedAt, startUtc.toIso8601String())
            .lt(EventEndpoints.detectedAt, endUtc.toIso8601String());
      }

      if (search != null && search.isNotEmpty) {
        final s = search.replaceAll("'", "''");
        query = query.or(
          '${EventEndpoints.eventType}.ilike.%$s%,'
          '${EventEndpoints.eventDescription}.ilike.%$s%',
        );
      }

      final from = (page - 1) * limit;
      final to = page * limit - 1;
      List<Map<String, dynamic>> normalized = [];

      try {
        final rows = await query
            .order(EventEndpoints.detectedAt, ascending: false)
            .range(from, to);

        _logRawRows(rows);
        debugPrint('[EventService] RAW rows len=${(rows as List).length}');

        for (final r in (rows as List)) {
          final m = await _normalizeRow(r as Map<String, dynamic>);
          normalized.add(m);
        }
      } catch (e, st) {
        dev.log(
          '[EventService] Supabase fetch failed, falling back to REST /events: $e',
          name: 'EventService.fetchLogs',
          stackTrace: st,
        );

        try {
          final ds = EventsRemoteDataSource();
          final list = await ds.listEvents();
          for (final r in list) {
            final m = await _normalizeRow(r);
            normalized.add(m);
          }
        } catch (restErr, restSt) {
          dev.log(
            '[EventService] REST fallback also failed: $restErr',
            name: 'EventService.fetchLogs',
            stackTrace: restSt,
          );
          return [];
        }
      }

      _logNormalizedSample(normalized);

      final filtered = (period == null || period.isEmpty || period == 'All')
          ? normalized
          : normalized
                .where((e) => _matchesPeriod(e['detectedAt'], period))
                .toList();

      return filtered.map(EventLog.fromJson).toList();
    } catch (e, st) {
      dev.log(
        '[EventService] Error fetching logs: $e',
        name: 'EventService.fetchLogs',
        stackTrace: st,
      );
      if (e is PostgrestException) {
        debugPrint(
          '[EventService] PostgrestException code=${e.code}, details=${e.details}, hint=${e.hint}, message=${e.message}',
        );
      }
      rethrow;
    }
  }

  Future<EventLog> proposeEventStatus({
    required String eventId,
    required String proposedStatus,
    String? proposedEventType,
    String? reason,
    DateTime? pendingUntil,
  }) async {
    try {
      if (eventId.trim().isEmpty) {
        throw Exception('ID sự kiện không hợp lệ. Vui lòng thử lại.');
      }
      final body = <String, dynamic>{
        'proposed_status': proposedStatus,
        if (proposedEventType != null && proposedEventType.isNotEmpty)
          'proposed_event_type': proposedEventType,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (pendingUntil != null)
          'pending_until': pendingUntil.toUtc().toIso8601String(),
      };

      dev.log(
        '📤 [EventService] proposeEventStatus($eventId): $body',
        name: 'EventService',
      );

      final res = await _api.post('/events/$eventId/propose', body: body);
      dev.log(
        '📥 [EventService] proposeEventStatus → ${res.statusCode}',
        name: 'EventService',
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = _api.extractDataFromResponse(res);
        if (decoded is Map<String, dynamic>) {
          return EventLog.fromJson(decoded);
        } else {
          throw Exception('Phản hồi không hợp lệ từ server.');
        }
      }

      String _messageFromResponse(http.Response r) {
        try {
          final decoded = _api.extractDataFromResponse(r);
          if (decoded is Map) {
            for (final key in ['message', 'error', 'detail', 'description']) {
              if (decoded.containsKey(key) && decoded[key] != null) {
                return decoded[key].toString();
              }
            }
            if (decoded.containsKey('errors')) {
              return decoded['errors'].toString();
            }
          }
        } catch (_) {}
        try {
          if (r.body.trim().isNotEmpty) return r.body;
        } catch (_) {}
        return 'Lỗi không xác định (${r.statusCode}).';
      }

      final serverMsg = _messageFromResponse(res);

      if (res.statusCode == 400) {
        throw Exception('Yêu cầu không hợp lệ hoặc sự kiện quá 72 giờ.');
      } else if (res.statusCode == 403) {
        throw Exception('Chỉ caregiver mới được phép gửi đề xuất.');
      } else if (res.statusCode == 409) {
        throw Exception('Sự kiện này đã trong danh sách chờ duyệt cập nhật');
      } else {
        throw Exception(serverMsg);
      }
    } catch (e, st) {
      dev.log(
        '❌ [EventService] proposeEventStatus error: $e',
        name: 'EventService',
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<EventLog> fetchLogDetail(String id) async {
    try {
      final row = await _supabase
          .from(EventEndpoints.eventsTable)
          .select(EventEndpoints.selectDetail)
          .eq(EventEndpoints.eventId, id)
          .single();

      final normalized = await _normalizeRow(row);
      return EventLog.fromJson(normalized);
    } catch (e) {
      dev.log(
        'Error fetching log detail: $e',
        name: 'EventService.fetchLogDetail',
      );
      rethrow;
    }
  }

  Future<EventLog> createLog(Map<String, dynamic> data) async {
    try {
      final row = await _supabase
          .from(EventEndpoints.eventsTable)
          .insert(data)
          .select(EventEndpoints.selectDetail)
          .single();

      final normalized = await _normalizeRow(row);
      return EventLog.fromJson(normalized);
    } catch (e) {
      dev.log('Error creating log: $e', name: 'EventService.createLog');
      rethrow;
    }
  }

  Future<void> deleteLog(String id) async {
    try {
      await _supabase
          .from(EventEndpoints.eventsTable)
          .delete()
          .eq(EventEndpoints.eventId, id);
    } catch (e) {
      dev.log('Error deleting log: $e', name: 'EventService.deleteLog');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _normalizeRow(Map<String, dynamic> row) async {
    final rawDetected = row[EventEndpoints.detectedAt];
    final dt = _parseDetectedAtAny(rawDetected);
    final detectedAtIso = dt?.toUtc().toIso8601String();

    return {
      'eventId': row[EventEndpoints.eventId],
      'eventType': row[EventEndpoints.eventType],
      'eventDescription': row[EventEndpoints.eventDescription],
      'confidenceScore': row[EventEndpoints.confidenceScore] ?? 0,
      'status': row[EventEndpoints.status],
      'detectedAt': detectedAtIso,
      'confirm_status': row[EventEndpoints.confirmStatus],
    };
  }

  DateTime? _parseDetectedAtAny(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      final norm = _normalizeIso8601(v);
      try {
        return DateTime.parse(norm);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _normalizeIso8601(String s) {
    var out = s.trim();
    if (out.contains(' ') && !out.contains('T')) {
      out = out.replaceFirst(' ', 'T');
    }
    out = out.replaceFirstMapped(RegExp(r'([+-]\d{2})$'), (m) => '${m[1]}:00');
    out = out.replaceFirst(RegExp(r'\+00(?::00)?$'), 'Z');
    return out;
  }

  bool _matchesPeriod(dynamic detectedAt, String period) {
    final dt = _parseDetectedAtAny(detectedAt);
    if (dt == null) return false;
    final h = dt.toLocal().hour;

    switch (period) {
      case 'All':
        return true;
      case 'Morning': // 05:00–11:59
        return h >= 5 && h < 12;
      case 'Afternoon': // 12:00–17:59
        return h >= 12 && h < 18;
      case 'Evening': // 18:00–21:59
        return h >= 18 && h < 22;
      case 'Night': // 22:00–04:59
        return h >= 22 || h < 5;
      default:
        return true;
    }
  }

  void _logRawRows(Object rows) {
    try {
      final list = rows as List;
      dev.log('RAW rows len=${list.length}', name: 'EventService.fetchLogs');

      final sample = list.take(3).map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return {
          'event_id': m[EventEndpoints.eventId],
          'event_type': m[EventEndpoints.eventType],
          'status': m[EventEndpoints.status],
          'detected_at': m[EventEndpoints.detectedAt],
          'snapshot_id': m[EventEndpoints.snapshotId],
          'snapshots': m['snapshots'],
        };
      }).toList();

      dev.log(
        'RAW sample(<=3)=${convert.jsonEncode(sample)}',
        name: 'EventService.fetchLogs',
      );
    } catch (err, st) {
      dev.log(
        'RAW log failed: $err',
        name: 'EventService.fetchLogs',
        stackTrace: st,
      );
    }
  }

  void _logNormalizedSample(List<Map<String, dynamic>> norm) {
    try {
      final sample = norm.take(3).toList();
      dev.log(
        'NORMALIZED sample(<=3)=${convert.jsonEncode(sample)}',
        name: 'EventService.fetchLogs',
      );
    } catch (err, st) {
      dev.log(
        'NORMALIZED log failed: $err',
        name: 'EventService.fetchLogs',
        stackTrace: st,
      );
    }
  }
}
