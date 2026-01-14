import 'package:detect_care_caregiver_app/core/providers/permissions_provider.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';

/// Kết quả validation cho việc edit/đề xuất event
class EventEditValidation {
  final bool canEdit;
  final String? reason;

  const EventEditValidation({required this.canEdit, this.reason});

  factory EventEditValidation.allowed() =>
      const EventEditValidation(canEdit: true);

  factory EventEditValidation.denied(String reason) =>
      EventEditValidation(canEdit: false, reason: reason);
}

/// Check xem user có thể edit/đề xuất thay đổi event không
///
/// Điều kiện:
/// 1. Permission "alert_ack": true
/// 2. Event created_at không quá 2 ngày
/// 3. confirmation_state phải là DETECTED hoặc REJECTED_BY_CUSTOMER
EventEditValidation canEditEvent({
  required EventLog event,
  required PermissionsProvider permissionsProvider,
  required String? customerId,
}) {
  // Check permission
  if (customerId == null || customerId.isEmpty) {
    return EventEditValidation.denied('Không thể xác định khách hàng');
  }

  final hasPermission = permissionsProvider.hasPermission(
    customerId,
    'alert_ack',
  );

  if (!hasPermission) {
    return EventEditValidation.denied(
      'Bạn không có quyền đề xuất thay đổi sự kiện. Quyền "Thay đổi sự kiện" đã bị thu hồi.',
    );
  }

  // Check created_at không quá 2 ngày
  final ref = event.createdAt ?? event.detectedAt;
  if (ref != null) {
    final age = DateTime.now().difference(ref);
    if (age > const Duration(days: 2)) {
      return EventEditValidation.denied(
        'Sự kiện đã quá 2 ngày, không thể đề xuất thay đổi.',
      );
    }
  }

  // Check confirmation_state: chỉ cho phép DETECTED hoặc REJECTED_BY_CUSTOMER
  final status = event.confirmationState?.toUpperCase();

  final canPropose = status == 'DETECTED' || status == 'REJECTED_BY_CUSTOMER';

  if (!canPropose) {
    return EventEditValidation.denied(
      'Sự kiện đã được thay đổi trước đó hoặc đang chờ duyệt, không thể đề xuất lần nữa.',
    );
  }

  return EventEditValidation.allowed();
}

/// Check đơn giản chỉ thời gian (cho timeline)
bool isEventWithin2Days(DateTime? createdAt, DateTime? detectedAt) {
  final ref = createdAt ?? detectedAt;
  if (ref == null) return true;
  return DateTime.now().difference(ref) < const Duration(days: 2);
}
