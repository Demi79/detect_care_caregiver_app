class BackendEnums {
  static String statusToVietnamese(String? status) {
    if (status == null) return 'Không xác định';
    switch (status) {
      case 'danger':
        return 'Nguy hiểm';
      case 'warning':
        return 'Cảnh báo';
      case 'normal':
        return 'Bình thường';
      case 'unknown':
        return 'Không xác định';
      case 'suspect':
        return 'Đáng ngờ';
      case 'abnormal':
        return 'Bất thường';
      default:
        return status;
    }
  }

  static String confirmStatusToVietnamese(dynamic confirm) {
    if (confirm is bool && confirm) return 'Xác nhận';
    return 'Chưa xác nhận';
  }

  static String eventTypeToVietnamese(String? type) {
    if (type == null) return 'Không xác định';
    switch (type) {
      case 'fall':
        return 'Ngã';
      case 'abnormal_behavior':
        return 'Hành vi bất thường';
      case 'emergency':
        return 'Tình huống khẩn cấp';
      case 'normal_activity':
        return 'Hoạt động bình thường';
      case 'sleep':
        return 'Ngủ nghỉ';
      default:
        return type;
    }
  }

  static const Map<String, String> daysOfWeekVi = {
    'monday': 'Thứ Hai',
    'tuesday': 'Thứ Ba',
    'wednesday': 'Thứ Tư',
    'thursday': 'Thứ Năm',
    'friday': 'Thứ Sáu',
    'saturday': 'Thứ Bảy',
    'sunday': 'Chủ nhật',
  };

  static String habitTypeToVietnamese(String? type) {
    if (type == null) return 'Không xác định';
    switch (type) {
      case 'sleep':
        return 'Ngủ nghỉ';
      case 'meal':
        return 'Ăn uống';
      case 'medication':
        return 'Uống thuốc';
      case 'activity':
        return 'Hoạt động';
      case 'bathroom':
        return 'Vệ sinh cá nhân';
      case 'therapy':
        return 'Trị liệu';
      case 'social':
        return 'Giao tiếp xã hội';
      default:
        return type;
    }
  }

  static String frequencyToVietnamese(String? freq) {
    if (freq == null) return 'Không xác định';
    switch (freq) {
      case 'daily':
        return 'Hằng ngày';
      case 'weekly':
        return 'Hằng tuần';
      case 'custom':
        return 'Tùy chọn';
      default:
        return freq;
    }
  }

  static String lifecycleStateToVietnamese(String? state) {
    if (state == null || state.trim().isEmpty) return 'Không xác định';

    switch (state.toUpperCase()) {
      case 'CANCELED':
        return 'Đã hủy';

      case 'NOTIFIED':
        return 'Đã gửi thông báo';

      case 'AUTOCALLED':
        return 'Đang gọi khẩn cấp tự động';

      case 'ALARM_ACTIVATED':
        return 'Chuông báo động đang kích hoạt';

      case 'ACKNOWLEDGED':
        return 'Đã phản hồi';

      case 'EMERGENCY_RESPONSE_RECEIVED':
        return 'Liên hệ khẩn cấp thành công';

      case 'RESOLVED':
        return 'Sự kiện đã được xử lý';

      case 'EMERGENCY_ESCALATION_FAILED':
        return 'Liên hệ khẩn cấp thất bại';

      default:
        return state;
    }
  }

  static String skipDurationToVietnamese(String? code) {
    if (code == null) return 'Không xác định';
    switch (code) {
      case '15m':
        return '15 phút';
      case '1h':
        return '1 giờ';
      case '8h':
        return '8 giờ';
      case '24h':
        return '24 giờ';
      case '2d':
        return '2 ngày';
      case '7d':
        return '7 ngày';
      case '30d':
        return '30 ngày';
      case 'until_change':
        return 'Cho đến khi thay đổi';
      case 'until_date':
        return 'Đến ngày đã chọn';
      default:
        return code;
    }
  }

  static String skipScopeToVietnamese(String? scope) {
    if (scope == null) return 'Không xác định';
    switch (scope) {
      case 'item':
        return 'Chỉ gợi ý này';
      case 'type':
        return 'Theo loại gợi ý';
      case 'all':
        return 'Tất cả gợi ý';
      default:
        return scope;
    }
  }

  static String businessTypeToVietnamese(String? type) {
    if (type == null) return 'Không xác định';
    switch (type) {
      case 'event_alert':
        return 'Cảnh báo sự kiện';
      case 'confirmation_request':
        return 'Yêu cầu xác nhận';
      case 'caregiver_invitation':
        return 'Mời người chăm sóc';
      case 'system_update':
        return 'Cập nhật hệ thống';
      case 'emergency_alert':
        return 'Cảnh báo khẩn cấp';
      case 'subscription_renewal':
        return 'Gia hạn gói dịch vụ';
      case 'quota_warning':
        return 'Cảnh báo giới hạn';
      default:
        return type;
    }
  }

  static const List<String> skipDurations = [
    '15m',
    '1h',
    '8h',
    '24h',
    '2d',
    '7d',
    '30d',
    'until_change',
    'until_date',
  ];

  static const List<String> skipScopes = ['item', 'type', 'all'];

  // Hằng số lifecycle được dùng chung ở client để tránh hardcode giá trị.
  static const String lifecycleForwarded = 'Forwarded';
}
