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

String? _findEventIdDeep(dynamic node) {
  if (node is Map) {
    final v1 = node['event_id'];
    if (v1 != null && v1.toString().isNotEmpty) return v1.toString();

    final v2 = node['eventId'];
    if (v2 != null && v2.toString().isNotEmpty) return v2.toString();

    for (final v in node.values) {
      final found = _findEventIdDeep(v);
      if (found != null && found.isNotEmpty) return found;
    }
  } else if (node is List) {
    for (final item in node) {
      final found = _findEventIdDeep(item);
      if (found != null && found.isNotEmpty) return found;
    }
  }
  return null;
}

String resolveEventId({
  required String clipId,
  required Map<String, dynamic> meta,
}) {
  final direct = pickString(meta, const ['event_id', 'eventId']);
  if (direct != null && direct.isNotEmpty) return direct;

  final nested = _findEventIdDeep(meta);
  if (nested != null && nested.isNotEmpty) return nested;

  final top = pickString(meta, const ['id']);
  if (top != null && top.isNotEmpty) return top;

  return clipId;
}

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
