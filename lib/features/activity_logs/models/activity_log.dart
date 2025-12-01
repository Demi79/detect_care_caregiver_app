import 'dart:convert';

class ActivityLog {
  final String id;
  final DateTime timestamp;
  final String actorId;
  final String? actorName;
  final String action;
  final String resourceType;
  final String? resourceId;
  final String? resourceName;
  final String message;
  final String severity;
  final String? actionEnum;
  final Map<String, dynamic> meta;
  final String? ip;

  ActivityLog({
    required this.id,
    required this.timestamp,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    required this.resourceName,
    required this.message,
    required this.severity,
    required this.actionEnum,
    required this.meta,
    required this.ip,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    DateTime parseTs(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.parse(v);
      }
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    Map<String, dynamic> m(dynamic v) =>
        (v is Map) ? v.cast<String, dynamic>() : <String, dynamic>{};

    return ActivityLog(
      id: json['id'] as String,
      timestamp: parseTs(json['timestamp']),
      actorId: json['actor_id'] as String,
      actorName: json['actor_name'] as String?,
      action: json['action'] as String,
      resourceType: json['resource_type'] as String,
      resourceId: json['resource_id'] as String?,
      resourceName: json['resource_name'] as String?,
      message: json['message'] as String,
      severity: json['severity'] as String,
      actionEnum: json['action_enum'] as String?,
      meta: m(json['meta']),
      ip: json['ip'] as String?,
    );
  }

  static List<ActivityLog> listFromJson(String body) {
    final raw = json.decode(body);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ActivityLog.fromJson)
          .toList();
    }
    return const <ActivityLog>[];
  }
}
