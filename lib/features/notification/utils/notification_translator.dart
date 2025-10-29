class NotificationTranslator {
  static const Map<String, String> businessTypeMap = {
    'event_alert': 'Cảnh báo sự kiện',
    'confirmation_request': 'Yêu cầu xác nhận',
    'caregiver_invitation': 'Lời mời người chăm sóc',
    'system_update': 'Cập nhật hệ thống',
    'emergency_alert': 'Khẩn cấp',
  };

  static const Map<String, String> statusMap = {
    'pending': 'Đang chờ',
    'sent': 'Đã gửi',
    'delivered': 'Đã giao',
    'failed': 'Thất bại',
    'bounced': 'Không đến được',
  };

  static const Map<String, String> priorityMap = {
    'low': 'Thấp',
    'normal': 'Bình thường',
    'high': 'Cao',
    'critical': 'Khẩn cấp',
  };

  static String businessType(String? key) => businessTypeMap[key] ?? key ?? '-';

  static String status(String? key) => statusMap[key] ?? key ?? '-';

  static String priority(String? key) => priorityMap[key] ?? key ?? '-';
}
