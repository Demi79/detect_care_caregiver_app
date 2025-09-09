enum NotificationType {
  systemEvent('system_event'),
  actorMessage('actor_message');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => systemEvent,
    );
  }
}

enum NotificationDirection {
  customerToCaregiver('customer_to_caregiver'),
  caregiverToCustomer('caregiver_to_customer');

  final String value;
  const NotificationDirection(this.value);

  static NotificationDirection? fromString(String? value) {
    if (value == null) return null;
    return NotificationDirection.values.firstWhere(
      (e) => e.value == value,
      orElse: () => customerToCaregiver,
    );
  }
}

enum SystemEventType {
  fall('fall'),
  seizure('seizure'),
  abnormalBehavior('abnormal_behavior');

  final String value;
  const SystemEventType(this.value);

  static SystemEventType? fromString(String? value) {
    if (value == null) return null;
    return SystemEventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => fall,
    );
  }

  String get title {
    switch (this) {
      case SystemEventType.fall:
        return "🚨 Fall Detected";
      case SystemEventType.seizure:
        return "🚨 Seizure Detected";
      case SystemEventType.abnormalBehavior:
        return "⚠️ Abnormal Behavior";
    }
  }
}

enum MessageCategory {
  help('help'),
  reminder('reminder'),
  report('report'),
  confirm('confirm');

  final String value;
  const MessageCategory(this.value);

  static MessageCategory? fromString(String? value) {
    if (value == null) return null;
    return MessageCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => help,
    );
  }

  String get title {
    switch (this) {
      case MessageCategory.help:
        return "🆘 Help Request";
      case MessageCategory.reminder:
        return "⏰ Reminder";
      case MessageCategory.report:
        return "📋 Report";
      case MessageCategory.confirm:
        return "✅ Confirmation";
    }
  }
}
