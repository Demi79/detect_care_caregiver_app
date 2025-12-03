import 'package:flutter/material.dart';

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
    'normal': 'Bình thường',
    'warning': 'Cảnh báo',
    'danger': 'Nguy hiểm',
  };

  static const Map<String, String> priorityMap = {
    'low': 'Thấp',
    'normal': 'Bình thường',
    'high': 'Cao',
    'critical': 'Khẩn cấp',
  };

  // Map status/severity keys to a display color
  static const Map<String, Color> _statusColorMap = {
    'danger': Color(0xFFB71C1C), // Red 900
    'critical': Color(0xFFB71C1C), // Red 900
    'warning': Color(0xFFEF6C00), // Orange 800
    'normal': Color(0xFF3B82F6), // Blue 500
    'info': Color(0xFF1B5E20), // Green 900
    'pending': Color(0xFFF57F17), // Amber 700 (more visible)
    'sent': Color(0xFF2E7D32), // Green 700
    'delivered': Color(0xFF1565C0), // Blue 800
    'failed': Color(0xFFB71C1C),
    'bounced': Color(0xFF374151), // Dark neutral
  };

  static String businessType(String? key) => businessTypeMap[key] ?? key ?? '-';

  static String status(String? key) => statusMap[key] ?? key ?? '-';

  static String priority(String? key) => priorityMap[key] ?? key ?? '-';

  static Color statusColor(String? key) {
    if (key == null) return const Color(0xFFF1F5F9);
    return _statusColorMap[key.toLowerCase()] ?? const Color(0xFFF1F5F9);
  }
}
