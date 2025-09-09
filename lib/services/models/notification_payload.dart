import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../core/enums/notification_types.dart';

class NotificationPayload {
  final NotificationType type;
  final NotificationDirection? direction;
  final SystemEventType? eventType;
  final MessageCategory? category;
  final String fromUserId;
  final String? eventId;
  final String? message;
  final String? deeplink;
  final Map<String, dynamic> rawData;

  const NotificationPayload._({
    required this.type,
    this.direction,
    this.eventType,
    this.category,
    required this.fromUserId,
    this.eventId,
    this.message,
    this.deeplink,
    required this.rawData,
  });

  factory NotificationPayload.fromFCM(RemoteMessage message) {
    final data = message.data;
    final typeStr = data['type'] ?? '';
    final fromUserId = data['fromUserId'] ?? '';

    // Log payload for debugging
    debugPrint('\n📥 FCM Payload:');
    data.forEach((key, value) => debugPrint('  $key: $value'));

    final payload = NotificationPayload._(
      type: NotificationType.fromString(typeStr),
      direction: NotificationDirection.fromString(data['direction']),
      eventType: SystemEventType.fromString(data['eventType']),
      category: MessageCategory.fromString(data['category']),
      fromUserId: fromUserId,
      eventId: data['eventId'],
      message: data['message'] ?? message.notification?.body,
      deeplink: data['deeplink'],
      rawData: data,
    );

    // Validate payload
    debugPrint('\n✅ Payload validation:');
    debugPrint('  Type: ${payload.type.value}');
    if (payload.isSystemEvent) {
      debugPrint('  System Event:');
      debugPrint('    Event Type: ${payload.eventType?.value}');
      debugPrint('    Event ID: ${payload.eventId}');
    } else {
      debugPrint('  Actor Message:');
      debugPrint('    Direction: ${payload.direction?.value}');
      debugPrint('    Category: ${payload.category?.value}');
    }
    debugPrint('  Valid: ${payload.isValid}');

    return payload;
  }

  bool get isSystemEvent => type == NotificationType.systemEvent;
  bool get isActorMessage => type == NotificationType.actorMessage;

  bool get isValid {
    if (fromUserId.isEmpty) return false;

    if (isSystemEvent) {
      return eventType != null && eventId != null;
    } else {
      return direction != null && category != null;
    }
  }

  String getTitle() {
    if (isSystemEvent) {
      return eventType?.title ?? 'System Alert';
    } else {
      if (direction == NotificationDirection.customerToCaregiver &&
          category == MessageCategory.help) {
        return category!.title;
      }
      return 'New Message';
    }
  }

  bool get requiresUrgentDisplay =>
      isSystemEvent || (isActorMessage && category == MessageCategory.help);

  /// Gets the deeplink path that should be used when user taps on the notification
  // String? get navigationPath {
  //   if (isSystemEvent) {
  //     // For system events, return null to let the modal handling take over
  //     return null;
  //   } else if (isActorMessage) {
  //     // For actor messages, navigate to appropriate chat/message screen
  //     if (direction == NotificationDirection.customerToCaregiver) {
  //       return '/customer/$fromUserId/chat';
  //     } else if (direction == NotificationDirection.caregiverToCustomer) {
  //       return '/caregiver/$fromUserId/chat';
  //     }
  //   }
  //   return null;
  // }

  /// Whether this notification should show a modal when opened from background
  bool get shouldShowModalOnOpen {
    // Only system events should show modal when opened from background
    return isSystemEvent && eventType != null && eventId != null;
  }

  @override
  String toString() =>
      '''
NotificationPayload(
  type: ${type.value}
  direction: ${direction?.value}
  eventType: ${eventType?.value}
  category: ${category?.value}
  fromUserId: $fromUserId
  eventId: $eventId
  message: $message
  deeplink: $deeplink
)''';
}
