import 'package:flutter/material.dart';

/// Input data for isolate processing
class EventIsolateInput {
  final List<Map<String, dynamic>> rawRows;
  final String? status;
  final DateTimeRange? dayRange;
  final String? period;
  final String? lifecycleState;

  EventIsolateInput({
    required this.rawRows,
    this.status,
    this.dayRange,
    this.period,
    this.lifecycleState,
  });
}

/// Process events in isolate: normalize + filter
List<Map<String, dynamic>> processEventsInIsolate(EventIsolateInput input) {
  // 1. Normalize
  final normalized = <Map<String, dynamic>>[];
  for (final row in input.rawRows) {
    normalized.add(_normalizeRow(row));
  }

  var working = List<Map<String, dynamic>>.from(normalized);

  // 2. Status filter
  if (input.status != null &&
      input.status!.isNotEmpty &&
      input.status!.toLowerCase() != 'all') {
    final st = input.status!.toLowerCase();

    if (st == 'abnormal') {
      working = working.where((e) {
        final s = (e['status']?.toString() ?? '').toLowerCase();
        return s == 'danger' || s == 'warning';
      }).toList();
    } else {
      working = working.where((e) {
        final s = (e['status']?.toString() ?? '').toLowerCase();
        return s == st;
      }).toList();
    }
  }

  // 3. Day range filter (FIX detected_at key)
  if (input.dayRange != null) {
    final startUtc = DateTime(
      input.dayRange!.start.year,
      input.dayRange!.start.month,
      input.dayRange!.start.day,
    ).toUtc();
    final endUtc = DateTime(
      input.dayRange!.end.year,
      input.dayRange!.end.month,
      input.dayRange!.end.day + 1,
    ).toUtc();

    working = working.where((e) {
      try {
        final dt = _parseDetectedAtAny(e['detected_at'] ?? e['detectedAt']);
        if (dt == null) return false;
        final t = dt.toUtc();
        return !t.isBefore(startUtc) && t.isBefore(endUtc);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // 4. Period filter
  final filtered =
      (input.period == null || input.period!.isEmpty || input.period == 'All')
      ? working
      : working
            .where(
              (e) => _matchesPeriod(
                e['detected_at'] ?? e['detectedAt'],
                input.period!,
              ),
            )
            .toList();

  // 5. Lifecycle filter (FIX full canceled variants)
  var finalList = List<Map<String, dynamic>>.from(filtered);
  if (input.lifecycleState == null || input.lifecycleState!.isEmpty) {
    finalList = finalList.where((e) {
      try {
        final ls = (e['lifecycle_state'] ?? e['lifecycleState'])?.toString();
        if (ls == null || ls.isEmpty) return true;

        final v = ls.toLowerCase();
        return !v.contains('cancel') &&
            !v.contains('deact') &&
            !v.contains('remove');
      } catch (_) {
        return true;
      }
    }).toList();
  }

  return finalList;
}

/// Normalize a single row
Map<String, dynamic> _normalizeRow(Map<String, dynamic> row) {
  final rawDetected = row['detected_at'] ?? row['detectedAt'];
  final dt = _parseDetectedAtAny(rawDetected);
  final detectedAtIso = dt?.toUtc().toIso8601String();

  return {
    'eventId': row['event_id'] ?? row['eventId'],
    'eventType': row['event_type'] ?? row['eventType'],
    'eventDescription': row['event_description'] ?? row['eventDescription'],
    'confidenceScore': row['confidence_score'] ?? row['confidenceScore'] ?? 0,
    'status': row['status'],
    'lifecycle_state': row['lifecycle_state'] ?? row['lifecycleState'],
    'detectedAt': detectedAtIso,
    'confirm_status': row['confirm_status'] ?? row['confirmStatus'],
  };
}

/// Parse detectedAt from various formats
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

/// Normalize ISO8601 string
String _normalizeIso8601(String s) {
  var out = s.trim();
  if (out.contains(' ') && !out.contains('T')) {
    out = out.replaceFirst(' ', 'T');
  }
  out = out.replaceFirstMapped(RegExp(r'([+-]\d{2})$'), (m) => '${m[1]}:00');
  out = out.replaceFirst(RegExp(r'\+00(?::00)?$'), 'Z');
  return out;
}

/// Match period filter
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
