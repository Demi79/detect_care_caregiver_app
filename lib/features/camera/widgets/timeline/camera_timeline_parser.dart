import 'package:flutter/material.dart';

import 'camera_timeline_components.dart';

List<CameraTimelineEntry> buildEntries(List<CameraTimelineClip> clips) {
  final sorted = [...clips]..sort((a, b) => b.startTime.compareTo(a.startTime));
  return sorted
      .map((c) => CameraTimelineEntry(time: c.startTime, clip: c))
      .toList();
}

List<CameraTimelineClip> parseRecordingClips(dynamic payload) {
  final items = _extractItems(payload);
  const colors = Colors.primaries;
  final clips = <CameraTimelineClip>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final recordingId = (item['id'] ?? item['recording_id'] ?? 'rec-$i')
        .toString();
    final timeValue =
        item['start'] ??
        item['start_time'] ??
        item['started_at'] ??
        item['recorded_at'];
    final started = _parseDate(timeValue);
    if (started == null) continue;
    final durationSeconds =
        _parseNum(item['duration_seconds']) ??
        _parseNum(item['duration']) ??
        _parseNum(item['length_seconds']) ??
        60;
    final clamped = durationSeconds.clamp(1, 3600).toInt();
    final duration = Duration(seconds: clamped);
    final accent = colors[(i * 2) % colors.length].shade400;
    final cameraId = item['camera_id']?.toString();
    final playUrl = item['play_url']?.toString() ?? item['playUrl']?.toString();
    final downloadUrl =
        item['download_url']?.toString() ?? item['downloadUrl']?.toString();
    final thumbnailUrl =
        item['thumbnail_url']?.toString() ?? item['thumbnailUrl']?.toString();
    final eventType =
        item['event_type']?.toString() ?? item['type']?.toString();
    Map<String, dynamic>? meta;
    if (item['metadata'] is Map) {
      meta = Map<String, dynamic>.from(item['metadata']);
    }
    meta ??= Map<String, dynamic>.from(item);
    try {
      // Keep recording ids normalized in metadata, but do NOT alias to snapshot_id.
      if ((meta['recording_id'] == null ||
              meta['recording_id'].toString().isEmpty) &&
          recordingId.isNotEmpty) {
        meta['recording_id'] = recordingId;
      }
      if ((meta['recordingId'] == null ||
              meta['recordingId'].toString().isEmpty) &&
          recordingId.isNotEmpty) {
        meta['recordingId'] = recordingId;
      }
    } catch (_) {}

    clips.add(
      CameraTimelineClip(
        kind: TimelineItemKind.recording,
        timelineItemId: recordingId,
        recordingId: recordingId,
        startTime: started,
        duration: duration,
        accent: accent,
        cameraId: cameraId,
        playUrl: playUrl,
        downloadUrl: downloadUrl,
        thumbnailUrl: thumbnailUrl,
        eventType: eventType,
        metadata: meta,
      ),
    );
  }
  return clips;
}

List<CameraTimelineClip> parseSnapshotClips(dynamic payload) {
  final items = _extractItems(payload);
  final colors = Colors.accents;
  final clips = <CameraTimelineClip>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final snapshotId = (item['id'] ?? item['snapshot_id'] ?? 'snap-$i')
        .toString();
    final timeValue = item['captured_at'] ?? item['created_at'] ?? item['time'];
    final captured = _parseDate(timeValue);
    if (captured == null) continue;
    final accent = colors[(i * 3) % colors.length];
    String? evtId;
    try {
      evtId =
          (item['event_id'] ?? item['eventId'] ?? item['event']?['event_id'])
              ?.toString();
      final snap =
          item['snapshot_id'] ??
          item['snapshotId'] ??
          item['snapshot']?['snapshot_id'];
      debugPrint(
        '[TimelineParser] snapshot item id=$snapshotId event_id=$evtId snapshot_id=$snap',
      );
    } catch (_) {}

    clips.add(
      CameraTimelineClip(
        kind: TimelineItemKind.snapshot,
        timelineItemId: snapshotId,
        snapshotId: snapshotId,
        eventId: (evtId != null && evtId.trim().isNotEmpty)
            ? evtId.trim()
            : null,
        startTime: captured,
        duration: const Duration(seconds: 5),
        accent: accent,
        metadata: Map<String, dynamic>.from(item),
      ),
    );
  }
  return clips;
}

List<CameraTimelineClip> parseEventClips(dynamic payload) {
  final items = _extractItems(payload);
  final colors = [
    Colors.deepPurple,
    Colors.indigo,
    Colors.teal,
    Colors.pinkAccent,
    Colors.blueGrey,
  ];
  final clips = <CameraTimelineClip>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final eventId = (item['event_id'] ?? item['id'] ?? 'evt-$i').toString();
    final timeValue =
        item['detected_at'] ??
        item['detectedAt'] ??
        item['created_at'] ??
        item['createdAt'] ??
        item['timestamp'] ??
        item['time'];
    final detected = _parseDate(timeValue);
    if (detected == null) continue;
    final rawDuration =
        _parseNum(item['duration_seconds']) ??
        _parseNum(item['duration']) ??
        45;
    final clamped = rawDuration.clamp(5, 600).toInt();
    final duration = Duration(seconds: clamped);
    final accent = colors[i % colors.length];
    clips.add(
      CameraTimelineClip(
        kind: TimelineItemKind.event,
        timelineItemId: eventId,
        eventId: eventId,
        // If the event payload references a snapshot id include it as well.
        snapshotId: (item['snapshot_id'] ?? item['snapshotId'])?.toString(),
        startTime: detected,
        duration: duration,
        accent: accent,
        eventType: item['event_type']?.toString() ?? item['type']?.toString(),
        metadata: Map<String, dynamic>.from(item),
      ),
    );
  }
  return clips;
}

List<Map<String, dynamic>> _extractItems(dynamic payload) {
  if (payload is List) {
    return payload
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (payload is Map) {
    final map = Map<String, dynamic>.from(payload);
    // First try top-level list keys (including 'records' which some backends use)
    for (final key in ['items', 'recordings', 'records', 'results']) {
      final value = map[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    // Some responses wrap the list under a `data` object, e.g. { data: { records: [...] } }
    final data = map['data'];
    if (data is Map) {
      for (final key in ['items', 'recordings', 'records', 'results']) {
        final value = data[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }

    return [map];
  }
  return const [];
}

int? _parseNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.round();
  return int.tryParse(value.toString());
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is num) {
    final millis = value > 1000000000000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
  }
  if (value is String) {
    if (value.isEmpty) return null;
    DateTime? parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    final normalized = value.contains('T')
        ? value
        : value.replaceFirst(' ', 'T');
    parsed = DateTime.tryParse(normalized);
    if (parsed != null) return parsed;
  }
  return null;
}
