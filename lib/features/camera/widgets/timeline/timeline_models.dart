import 'package:flutter/material.dart';

import 'timeline_utils.dart';

enum TimelineItemKind { event, snapshot, recording }

class CameraTimelineClip {
  /// The kind of timeline item — event, snapshot, or recording.
  final TimelineItemKind kind;

  /// Canonical timeline item id (the id returned by the backend for the
  /// timeline list record). This was previously called `id`.
  final String timelineItemId;

  /// Optional canonical ids (only one will be populated depending on kind):
  final String? eventId;
  final String? snapshotId;
  final String? recordingId;

  final DateTime startTime;
  final Duration duration;
  final Color accent;
  final String? cameraId;
  final String? playUrl;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final String? eventType;
  final Map<String, dynamic>? metadata;

  const CameraTimelineClip({
    required this.kind,
    required this.timelineItemId,
    required this.startTime,
    required this.duration,
    required this.accent,
    this.eventId,
    this.snapshotId,
    this.recordingId,
    this.cameraId,
    this.playUrl,
    this.downloadUrl,
    this.thumbnailUrl,
    this.eventType,
    this.metadata,
  });

  // Backwards-compatible accessors used throughout the codebase.
  String get id => timelineItemId;
  String get timelineEntryId => timelineItemId;
  String get selectionKey => '${timelineItemId}|${startTime.toIso8601String()}';

  String get timeLabel => formatHmsVn(startTime);

  String get durationLabel {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return "${minutes.toString().padLeft(1, '0')}'${seconds.toString().padLeft(2, '0')}\"";
  }
}

class CameraTimelineEntry {
  final DateTime time;
  final CameraTimelineClip? clip;

  const CameraTimelineEntry({required this.time, this.clip});

  String get timeLabel => formatHmVn(time);
}

class CameraTimelineModeOption {
  final IconData icon;
  final String label;

  const CameraTimelineModeOption(this.icon, this.label);
}
