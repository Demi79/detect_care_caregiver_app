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
        print('[EventService.fetchLogs] No Supabase session found');
        return [];
      }

      print(
        'filters status=$status, dayRange=${dayRange != null ? "${dayRange.start}..${dayRange.end}" : "null"}, period=$period, search=$search, page=$page, limit=$limit',
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
        print('[EventService] RAW rows len=${(rows as List).length}');

        for (final r in (rows as List)) {
          final m = await _normalizeRow(r as Map<String, dynamic>);
          normalized.add(m);
        }
      } catch (e) {
        print(
          '[EventService] Supabase fetch failed, falling back to REST /events: $e',
        );

        try {
          final ds = EventsRemoteDataSource();
          // Pass through the caller's page/limit so REST fallback returns
          // a matching page size (backend default may be 10).
          final list = await ds.listEvents(page: page, limit: limit);
          for (final r in list) {
            final m = await _normalizeRow(r);
            normalized.add(m);
          }
        } catch (restErr) {
          print('[EventService] REST fallback also failed: $restErr');
          return [];
        }
      }

      _logNormalizedSample(normalized);

      try {
        final sampleNorm = normalized
            .take(50)
            .map(
              (m) => {
                'eventId': m['eventId'] ?? m['event_id'] ?? m['id'],
                'confirm':
                    m['confirm_status'] ??
                    m['confirmed'] ??
                    m['confirmStatus'] ??
                    m['confirmationState'],
              },
            )
            .toList();
        print(
          '[EventService] NORMALIZED length=${normalized.length} sample=$sampleNorm',
        );
      } catch (_) {}

      List<Map<String, dynamic>> working = List.from(normalized);

      if (status != null &&
          status.isNotEmpty &&
          status.toLowerCase() != 'all') {
        if (status.toLowerCase() == 'abnormal') {
          working = working.where((e) {
            final s = (e['status']?.toString() ?? '').toLowerCase();
            return s == 'danger' || s == 'warning';
          }).toList();
        } else {
          working = working
              .where(
                (e) =>
                    (e['status']?.toString() ?? '').toLowerCase() ==
                    status.toLowerCase(),
              )
              .toList();
        }
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
        print(
          '[EventService.fetchLogs] Applying dayRange filter: startUtc=$startUtc endUtc=$endUtc (local start=${dayRange.start} end=${dayRange.end})',
        );

        try {
          final sample = working.take(8).map((e) => e['detectedAt']).toList();
          print(
            '[EventService.fetchLogs] Sample normalized detectedAt (raw): $sample',
          );
          for (final s in sample) {
            try {
              final parsed = _parseDetectedAtAny(s);
              print(
                '[EventService.fetchLogs] parsed detectedAt sample: raw=$s parsed=${parsed?.toUtc()}',
              );
            } catch (_) {}
          }
        } catch (_) {}

        working = working.where((e) {
          try {
            final dt = _parseDetectedAtAny(e['detectedAt']);
            if (dt == null) return false;
            final t = dt.toUtc();
            return !t.isBefore(startUtc) && t.isBefore(endUtc);
          } catch (_) {
            return false;
          }
        }).toList();
      }

      final filtered = (period == null || period.isEmpty || period == 'All')
          ? working
          : working
                .where((e) => _matchesPeriod(e['detectedAt'], period))
                .toList();

      try {
        final sampleFiltered = filtered
            .take(50)
            .map(
              (m) => {
                'eventId': m['eventId'] ?? m['event_id'] ?? m['id'],
                'confirm':
                    m['confirm_status'] ??
                    m['confirmed'] ??
                    m['confirmStatus'] ??
                    m['confirmationState'],
              },
            )
            .toList();
        print(
          '[EventService] FILTERED length=${filtered.length} sample=$sampleFiltered',
        );
      } catch (_) {}

      try {
        for (final row in filtered) {
          try {
            final id =
                row[EventEndpoints.eventId] ??
                row['event_id'] ??
                row['eventId'];
            final ca = row['created_at'] ?? row['createdAt'];
            print('[EventService.fetchLogs] row event=${id} created_at=$ca');
          } catch (_) {}
        }
      } catch (_) {}

      return filtered.map(EventLog.fromJson).toList();
    } catch (e) {
      print('[EventService.fetchLogs] Error fetching logs: $e');
      if (e is PostgrestException) {
        print(
          '[EventService] PostgrestException code=${e.code}, details=${e.details}, hint=${e.hint}, message=${e.message}',
        );
      }
      rethrow;
    }
  }

  Future<EventLog> fetchLogDetail(String id) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        try {
          print('[EventService] fetchLogDetail: using Supabase for id=$id');
          final row = await _supabase
              .from(EventEndpoints.eventsTable)
              .select(EventEndpoints.selectDetail)
              .eq(EventEndpoints.eventId, id)
              .single();

          final normalized = await _normalizeRow(row);
          return EventLog.fromJson(normalized);
        } catch (e) {
          print(
            '[EventService] Supabase fetchLogDetail failed: $e — will try backend API fallback',
          );
        }
      } else {
        print(
          '[EventService] No Supabase session available — will try backend API fallback for id=$id',
        );
      }

      print('[EventService] fetchLogDetail: calling backend API /events/$id');
      final res = await _api.get('/events/$id');
      print('[EventService] backend fetch status=${res.statusCode}');
      if (res.statusCode == 200) {
        final data = _api.extractDataFromResponse(res);
        return EventLog.fromJson(data);
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        throw Exception(
          'Không có quyền truy cập dữ liệu sự kiện (${res.statusCode})',
        );
      } else if (res.statusCode == 404) {
        throw Exception('Không tìm thấy sự kiện (404)');
      } else {
        throw Exception('Lỗi khi tải dữ liệu sự kiện (${res.statusCode})');
      }
    } catch (e) {
      print('[EventService.fetchLogDetail] Error fetching log detail: $e');
      if (e is PostgrestException) {
        print(
          '[EventService] PostgrestException in fetchLogDetail: code=${e.code}, message=${e.message}, details=${e.details}',
        );
        if (e.code == '42501' ||
            e.message.toLowerCase().contains('permission denied')) {
          throw Exception(
            'Không có quyền truy cập dữ liệu sự kiện (${e.message})',
          );
        }
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
        throw Exception('Yêu cầu không hợp lệ hoặc dữ liệu sai định dạng.');
      } else if (res.statusCode == 403) {
        throw Exception('Chỉ caregiver mới được phép gửi đề xuất.');
      } else if (res.statusCode == 409) {
        throw Exception('Đã có đề xuất chờ duyệt cho sự kiện này.');
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
