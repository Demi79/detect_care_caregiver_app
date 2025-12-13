import 'package:flutter/material.dart';
import 'timeline_utils.dart';

class CameraTimelineClip {
  final String id;
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
    required this.id,
    required this.startTime,
    required this.duration,
    required this.accent,
    this.cameraId,
    this.playUrl,
    this.downloadUrl,
    this.thumbnailUrl,
    this.eventType,
    this.metadata,
  });

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
