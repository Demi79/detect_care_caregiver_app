import 'package:flutter/foundation.dart';

enum NotificationType {
  warning('warning', 'Cảnh báo'),
  reminder('reminder', 'Nhắc nhở'),
  update('update', 'Cập nhật'),
  emergency('emergency', 'Khẩn cấp'),
  system('system', 'Hệ thống');

  const NotificationType(this.value, this.displayName);
  final String value;
  final String displayName;

  static NotificationType fromString(String value) {
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
  final int? priority;

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
    this.priority = 0,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    debugPrint('🔔 Parsing notification: $json');
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: NotificationType.fromString(json['type'] ?? 'system'),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isRead: json['is_read'] ?? false,
      patientId: json['patient_id']?.toString(),
      patientName: json['patient_name'],
      metadata: json['metadata'],
      actionUrl: json['action_url'],
      priority: json['priority'] ?? 0,
    );
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
      'priority': priority,
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
    int? priority,
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
      priority: priority ?? this.priority,
    );
  }

  /// Kiểm tra xem notification có phải là khẩn cấp không
  bool get isEmergency => type == NotificationType.emergency;

  /// Kiểm tra xem notification có phải là cảnh báo không
  bool get isWarning => type == NotificationType.warning;

  String get iconName {
    switch (type) {
      case NotificationType.warning:
        return 'warning';
      case NotificationType.reminder:
        return 'medication';
      case NotificationType.update:
        return 'update';
      case NotificationType.emergency:
        return 'emergency';
      case NotificationType.system:
        return 'notifications';
    }
  }

  String get colorHex {
    switch (type) {
      case NotificationType.warning:
        return '#FF6B35';
      case NotificationType.reminder:
        return '#4CAF50';
      case NotificationType.update:
        return '#2196F3';
      case NotificationType.emergency:
        return '#F44336';
      case NotificationType.system:
        return '#9E9E9E';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, type: $type, isRead: $isRead, timestamp: $timestamp)';
  }
}

/// Model cho danh sách notifications với pagination
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
    final actualData =
        json.containsKey('data') && json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final notifications =
        (actualData['data'] as List<dynamic>?)
            ?.map(
              (item) =>
                  NotificationModel.fromJson(item as Map<String, dynamic>),
            )
            .toList() ??
        [];

    return NotificationListResponse(
      notifications: notifications,
      totalCount: actualData['total'] ?? actualData['total_count'] ?? 0,
      page: actualData['page'] ?? 1,
      pageSize: actualData['limit'] ?? actualData['page_size'] ?? 20,
      hasNextPage: actualData['has_next_page'] ?? false,
      hasPreviousPage: actualData['has_previous_page'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications': notifications.map((n) => n.toJson()).toList(),
      'total_count': totalCount,
      'page': page,
      'page_size': pageSize,
      'has_next_page': hasNextPage,
      'has_previous_page': hasPreviousPage,
    };
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
    final params = <String, dynamic>{};

    if (type != null) params['type'] = type!.value;
    if (isRead != null) params['is_read'] = isRead!;
    if (startDate != null) params['start_date'] = startDate!.toIso8601String();
    if (endDate != null) params['end_date'] = endDate!.toIso8601String();
    if (patientId != null) params['patient_id'] = patientId!;
    if (priority != null) params['priority'] = priority!;

    return params;
  }
}
