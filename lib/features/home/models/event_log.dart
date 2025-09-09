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
  });
  factory EventLog.fromJson(Map<String, dynamic> json) {
    print('\n📥 [EventLog] Parsing JSON:');
    print('Input data:');
    json.forEach((k, v) => print('  $k: $v (${v?.runtimeType})'));

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

    // ---- Event ID (dùng cả snake & camel)
    final rawEventId = first(json, ['event_id', 'eventId', 'id']);
    print('\n🆔 [EventLog] Event ID parsing:');
    print(
      '  Raw value from JSON (first match): $rawEventId (${rawEventId?.runtimeType})',
    );
    final parsedEventId = s(rawEventId) ?? '';
    print('  Final parsed value: $parsedEventId');

    // ---- Confirm status: LẤY TỪ first(...) và DÙNG nó
    final confirmKeys = [
      'confirm_status',
      'confirmed',
      'confirmStatus',
      'is_confirmed',
    ];
    print('\n🔍 [EventLog] Checking all confirm status keys:');
    for (final key in confirmKeys) {
      print('  $key: ${json[key]} (${json[key]?.runtimeType})');
    }

    final rawConfirm = first(json, confirmKeys);
    final parsedConfirm = _parseConfirmStatus(rawConfirm);
    print('\n✅ [EventLog] Confirm status result:');
    print('  Selected raw value: $rawConfirm (${rawConfirm?.runtimeType})');
    print('  Final parsed value: $parsedConfirm');
    print('  Parse logic used: ${_getParseLogicUsed(rawConfirm)}');

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
      detectionData: m(first(json, ['detection_data', 'detectionData'])),
      aiAnalysisResult: m(
        first(json, ['ai_analysis_result', 'aiAnalysisResult']),
      ),
      contextData: m(first(json, ['context_data', 'contextData'])),
      boundingBoxes: m(first(json, ['bounding_boxes', 'boundingBoxes'])),
      confirmStatus: parsedConfirm, // <-- dùng parsedConfirm
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

  static String _getParseLogicUsed(dynamic value) {
    if (value == null) return 'Null value -> false';
    if (value is bool) return 'Direct boolean value';
    if (value is num) return 'Number value (!= 0)';
    if (value is String) {
      final s = value.trim().toLowerCase();
      if (['true', 't', '1', 'yes', 'y'].contains(s)) {
        return 'String matched positive value: "$s"';
      }
      if (['false', 'f', '0', 'no', 'n'].contains(s)) {
        return 'String matched negative value: "$s"';
      }
      return 'String did not match any known values: "$s" -> false';
    }
    return 'Unknown type ${value.runtimeType} -> false';
  }

  EventLog copyWith({String? status, bool? confirmStatus}) => EventLog(
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
  );
}
