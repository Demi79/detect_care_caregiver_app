import 'dart:developer' as dev;
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';

class EventLog implements LogEntry {
  @override
  final String eventId;
  @override
  final String status;
  @override
  final String eventType;
  @override
  final String? eventDescription;
  @override
  final double confidenceScore;
  @override
  final DateTime? detectedAt;
  @override
  final DateTime? createdAt;
  @override
  final Map<String, dynamic> detectionData;
  @override
  final Map<String, dynamic> aiAnalysisResult;
  @override
  final Map<String, dynamic> contextData;
  @override
  final Map<String, dynamic> boundingBoxes;
  @override
  final bool confirmStatus;

  final String? confirmationState;
  final String? proposedStatus;
  final String? previousStatus;
  final String? proposedBy;
  final String? pendingReason;
  final DateTime? pendingUntil;

  EventLog({
    required this.eventId,
    required this.status,
    required this.eventType,
    this.eventDescription,
    required this.confidenceScore,
    this.detectedAt,
    this.createdAt,
    this.detectionData = const {},
    this.aiAnalysisResult = const {},
    this.contextData = const {},
    this.boundingBoxes = const {},
    required this.confirmStatus,
    this.confirmationState,
    this.proposedStatus,
    this.previousStatus,
    this.proposedBy,
    this.pendingReason,
    this.pendingUntil,
  });

  factory EventLog.fromJson(Map<String, dynamic> json) {
    dev.log('\n📥 [EventLog] Parsing JSON:');
    json.forEach((k, v) => dev.log('  $k: $v (${v?.runtimeType})'));

    String? s(dynamic v) => v?.toString();
    double d(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    Map<String, dynamic> m(dynamic v) =>
        (v is Map) ? v.cast<String, dynamic>() : <String, dynamic>{};

    dynamic first(Map j, List<String> keys) {
      for (final k in keys) {
        if (j.containsKey(k) && j[k] != null) return j[k];
      }
      return null;
    }

    DateTime? dt(dynamic v) {
      if (v == null || (v is String && v.isEmpty)) return null;
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

    final rawEventId = first(json, ['event_id', 'eventId', 'id']);
    final parsedEventId = s(rawEventId) ?? '';

    final confirmKeys = [
      'confirm_status',
      'confirmed',
      'confirmStatus',
      'is_confirmed',
    ];
    final rawConfirm = first(json, confirmKeys);
    final parsedConfirm = _parseConfirmStatus(rawConfirm);
    // normalize context/detection maps and ensure camera id is present in contextData
    final ctxMap = m(first(json, ['context_data', 'contextData']));
    final detMap = m(first(json, ['detection_data', 'detectionData']));
    // top-level camera id fallback
    final topCamera = first(json, ['camera_id', 'cameraId', 'camera']);
    if (topCamera != null && topCamera.toString().isNotEmpty) {
      if (!ctxMap.containsKey('camera_id') && !ctxMap.containsKey('camera')) {
        ctxMap['camera_id'] = topCamera;
      }
      if (!detMap.containsKey('camera_id') && !detMap.containsKey('camera')) {
        detMap['camera_id'] = topCamera;
      }
    }

    return EventLog(
      eventId: parsedEventId,
      status: s(first(json, ['status'])) ?? '',
      eventType: s(first(json, ['event_type', 'eventType'])) ?? '',
      eventDescription: s(
        first(json, ['event_description', 'eventDescription']),
      ),
      confidenceScore: d(
        first(json, ['confidence_score', 'confidenceScore', 'confidence']),
      ),
      detectedAt: dt(first(json, ['detected_at', 'detectedAt'])),
      createdAt: dt(first(json, ['created_at', 'createdAt'])),
      detectionData: detMap,
      aiAnalysisResult: m(
        first(json, ['ai_analysis_result', 'aiAnalysisResult']),
      ),
      contextData: ctxMap,
      boundingBoxes: m(first(json, ['bounding_boxes', 'boundingBoxes'])),
      confirmStatus: parsedConfirm,
      confirmationState: s(
        first(json, ['confirmation_state', 'confirmationState']),
      ),
      proposedStatus: s(first(json, ['proposed_status', 'proposedStatus'])),
      previousStatus: s(first(json, ['previous_status', 'previousStatus'])),
      proposedBy: s(first(json, ['proposed_by', 'proposedBy'])),
      pendingReason: s(first(json, ['pending_reason', 'pendingReason'])),
      pendingUntil: dt(first(json, ['pending_until', 'pendingUntil'])),
    );
  }

  Map<String, dynamic> toMapString() {
    return {
      'event_id': eventId,
      'status': status,
      'event_type': eventType,
      'event_description': eventDescription,
      'confidence_score': confidenceScore,
      if (detectedAt != null) 'detected_at': detectedAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'detection_data': detectionData,
      'ai_analysis_result': aiAnalysisResult,
      'context_data': contextData,
      'bounding_boxes': boundingBoxes,
      'confirm_status': confirmStatus,
      'confirmation_state': confirmationState,
      'proposed_status': proposedStatus,
      'previous_status': previousStatus,
      'proposed_by': proposedBy,
      'pending_reason': pendingReason,
      if (pendingUntil != null)
        'pending_until': pendingUntil!.toIso8601String(),
    };
  }

  static String _normalizeIso8601(String s) {
    var out = s.trim();
    if (out.contains(' ') && !out.contains('T')) {
      out = out.replaceFirst(' ', 'T');
    }
    out = out.replaceFirstMapped(RegExp(r'([+-]\d{2})$'), (m) => '${m[1]}:00');
    out = out.replaceFirst(RegExp(r'\+00(?::00)?$'), 'Z');
    return out;
  }

  static bool _parseConfirmStatus(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      if (['true', 't', '1', 'yes', 'y'].contains(s)) return true;
      if (['false', 'f', '0', 'no', 'n'].contains(s)) return false;
    }
    return false;
  }

  EventLog copyWith({
    String? status,
    bool? confirmStatus,
    String? proposedStatus,
    String? pendingReason,
    String? confirmationState,
  }) => EventLog(
    eventId: eventId,
    status: status ?? this.status,
    eventType: eventType,
    eventDescription: eventDescription,
    confidenceScore: confidenceScore,
    detectedAt: detectedAt,
    createdAt: createdAt,
    detectionData: detectionData,
    aiAnalysisResult: aiAnalysisResult,
    contextData: contextData,
    boundingBoxes: boundingBoxes,
    confirmStatus: confirmStatus ?? this.confirmStatus,
    proposedStatus: proposedStatus ?? this.proposedStatus,
    pendingReason: pendingReason ?? this.pendingReason,
    confirmationState: confirmationState ?? this.confirmationState,
  );
}
