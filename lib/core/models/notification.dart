import 'package:intl/intl.dart';

enum NotificationType {
  warning('warning', 'Cảnh báo'),
  reminder('reminder', 'Nhắc nhở'),
  update('update', 'Cập nhật'),
  emergency('emergency', 'Khẩn cấp'),
  system('system', 'Hệ thống');

  const NotificationType(this.value, this.displayName);
  final String value;
  final String displayName;

  static NotificationType fromString(String? value) {
    if (value == null) return NotificationType.system;
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.system,
    );
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? patientId;
  final String? patientName;
  final Map<String, dynamic>? metadata;
  final String? actionUrl;
  final String? businessType;
  final int? priority;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? readAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.patientId,
    this.patientName,
    this.metadata,
    this.actionUrl,
    this.businessType,
    this.priority = 0,
    this.createdAt,
    this.updatedAt,
    this.readAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id:
          json['id']?.toString() ??
          json['notification_id']?.toString() ??
          json['uuid']?.toString() ??
          '',
      title:
          json['title'] ??
          (json['delivery_data'] is Map
              ? json['delivery_data']['title']
              : null) ??
          '',
      message: json['message'] ?? json['body'] ?? '',
      type: NotificationType.fromString(
        json['type'] ?? json['severity'] ?? 'system',
      ),
      timestamp: (() {
        final t =
            json['timestamp'] ??
            json['created_at'] ??
            json['sent_at'] ??
            json['updated_at'];
        if (t is String) {
          try {
            return DateTime.parse(t);
          } catch (_) {
            return DateTime.now();
          }
        }
        return DateTime.now();
      })(),
      isRead: json['is_read'] ?? (json['read_at'] != null),
      patientId: json['patient_id']?.toString(),
      patientName: json['patient_name']?.toString(),
      metadata:
          json['metadata'] ??
          (json['delivery_data'] is Map
              ? Map<String, dynamic>.from(json['delivery_data'])
              : null),
      actionUrl: json['action_url'] ?? json['actionUrl'],
      businessType:
          json['business_type'] ??
          json['businessType'] ??
          json['channel'] ??
          'system_update',
      priority: json['priority'] is int
          ? json['priority']
          : int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      readAt: _parseDate(json['read_at']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.value,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'patient_id': patientId,
      'patient_name': patientName,
      'metadata': metadata,
      'action_url': actionUrl,
      'business_type': businessType,
      'priority': priority,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    String? patientId,
    String? patientName,
    Map<String, dynamic>? metadata,
    String? actionUrl,
    String? businessType,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      metadata: metadata ?? this.metadata,
      actionUrl: actionUrl ?? this.actionUrl,
      businessType: businessType ?? this.businessType,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readAt: readAt ?? this.readAt,
    );
  }

  bool get isEmergency => type == NotificationType.emergency;
  bool get isWarning => type == NotificationType.warning;
  bool get hasBeenRead => isRead || readAt != null;

  String get createdAtFormatted => createdAt != null
      ? DateFormat('HH:mm dd/MM/yyyy').format(createdAt!)
      : '';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NotificationModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Notification(id: $id, title: $title, type: ${type.value}, read: $isRead)';
}

class NotificationListResponse {
  final List<NotificationModel> notifications;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const NotificationListResponse({
    required this.notifications,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] : json;
    final rawList = data['data'] ?? data['notifications'] ?? [];
    final list = <NotificationModel>[];

    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          list.add(NotificationModel.fromJson(item));
        }
      }
    }

    return NotificationListResponse(
      notifications: list,
      totalCount: data['total'] ?? data['total_count'] ?? list.length,
      page: data['page'] ?? 1,
      pageSize: data['page_size'] ?? 20,
      hasNextPage: data['has_next_page'] ?? false,
      hasPreviousPage: data['has_previous_page'] ?? false,
    );
  }
}

class NotificationFilter {
  final NotificationType? type;
  final bool? isRead;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? patientId;
  final int? priority;

  const NotificationFilter({
    this.type,
    this.isRead,
    this.startDate,
    this.endDate,
    this.patientId,
    this.priority,
  });

  Map<String, dynamic> toQueryParams() {
    return {
      if (type != null) 'type': type!.value,
      if (isRead != null) 'is_read': isRead,
      if (startDate != null) 'start_date': startDate!.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
      if (patientId != null) 'patient_id': patientId,
      if (priority != null) 'priority': priority,
    };
  }
}
