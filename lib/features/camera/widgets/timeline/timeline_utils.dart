import 'package:flutter/material.dart';

const _kVnOffset = Duration(hours: 7);

DateTime toVnTime(DateTime dt) => dt.toUtc().add(_kVnOffset);

String _two(int n) => n.toString().padLeft(2, '0');

String formatHmsVn(DateTime dt) {
  final t = toVnTime(dt);
  return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}

String formatHmVn(DateTime dt) {
  final t = toVnTime(dt);
  return '${_two(t.hour)}:${_two(t.minute)}';
}

extension ColorOpacitySafe on Color {
  Color withOpacitySafe(double opacity) {
    final a = (opacity * 255).round().clamp(0, 255);
    return withAlpha(a);
  }
}

String? pickString(Map<String, dynamic> src, List<String> keys) {
  for (final k in keys) {
    final v = src[k];
    if (v == null) continue;
    if (v is String) return v.isNotEmpty ? v : null;
    return v.toString();
  }
  return null;
}

Map<String, dynamic> pickMap(Map<String, dynamic> src, List<String> keys) {
  for (final k in keys) {
    final v = src[k];
    if (v is Map) return Map<String, dynamic>.from(v);
  }
  return const <String, dynamic>{};
}

double toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

String? resolveEventIdStrict(Map<String, dynamic> meta) {
  final direct = meta['event_id'] ?? meta['eventId'];
  if (direct != null) {
    final trimmed = direct.toString().trim();
    if (trimmed.isNotEmpty) return trimmed;
  }

  final ev = meta['event'];
  if (ev is Map) {
    final nested = ev['event_id'] ?? ev['eventId'] ?? ev['id'];
    if (nested != null) {
      final trimmed = nested.toString().trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
  }

  return null;
}

String resolveEventId({
  required String clipId,
  required Map<String, dynamic> meta,
}) => resolveEventIdStrict(meta) ?? '';

List<String> collectImageUrls(Map<String, dynamic> meta, {String? thumb}) {
  final set = <String>{};
  if (thumb != null && thumb.trim().isNotEmpty) set.add(thumb.trim());

  void collect(dynamic v) {
    if (v is String && v.trim().isNotEmpty) {
      set.add(v.trim());
      return;
    }
    if (v is Map) {
      final candidate = v['cloud_url'] ?? v['url'];
      if (candidate is String && candidate.trim().isNotEmpty) {
        set.add(candidate.trim());
      }
      return;
    }
    if (v is List) {
      for (final item in v) {
        collect(item);
      }
    }
  }

  collect(meta['cloud_url']);
  collect(meta['cloud_urls']);
  collect(meta['snapshot_url']);
  collect(meta['snapshot_urls']);
  collect(meta['image_url']);
  collect(meta['image_urls']);
  collect(meta['context_image']);

  return set.toList();
}

bool timelineCanEdit(EventLogLike event) {
  final ref = event.createdAt ?? event.detectedAt;
  if (ref == null) return true;
  return DateTime.now().difference(ref) < const Duration(days: 2);
}

/// Lightweight interface to avoid import cycles when only timestamps are needed.
class EventLogLike {
  final DateTime? createdAt;
  final DateTime? detectedAt;

  EventLogLike({this.createdAt, this.detectedAt});
}
