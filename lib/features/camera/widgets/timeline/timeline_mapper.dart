import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'timeline_utils.dart';
import 'timeline_models.dart';

EventLog buildTimelineEventLog(CameraTimelineClip clip, CameraEntry camera) {
  final meta = clip.metadata ?? const <String, dynamic>{};

  final status =
      pickString(meta, const ['status', 'event_status', 'lifecycle_state']) ??
      pickString(meta, const ['status_code', 'result']) ??
      'unknown';

  final eventType = pickString(meta, const ['event_type', 'type']) ?? 'unknown';

  final confidence = toDouble(
    meta['confidence_score'] ?? meta['confidence'] ?? meta['score'] ?? 0,
  );

  final eventId = resolveEventId(clipId: clip.id, meta: meta);

  AppLogger.d('[Timeline] Resolved eventId=$eventId from clip.id=${clip.id}');
  try {
    debugPrint(
      '[Timeline] Resolved eventId=$eventId source=${eventId == clip.id ? 'clip.id(snapshot)' : 'meta'} clip.id=${clip.id}',
    );
  } catch (_) {}

  return EventLog(
    eventId: eventId,
    status: status,
    eventType: eventType,
    eventDescription: pickString(meta, const ['description', 'message']),
    confidenceScore: confidence,
    detectedAt: clip.startTime,
    createdAt: clip.startTime,
    detectionData: Map<String, dynamic>.from(meta),
    contextData: pickMap(meta, const ['context_data', 'contextData']),
    boundingBoxes: pickMap(meta, const ['bounding_boxes', 'boundingBoxes']),
    confirmStatus: (meta['confirm_status'] ?? meta['confirmed']) == true,
    lifecycleState: pickString(meta, const [
      'lifecycle_state',
      'lifecycleState',
    ]),
    cameraId: camera.id,
    imageUrls: collectImageUrls(meta, thumb: clip.thumbnailUrl),
  );
}
