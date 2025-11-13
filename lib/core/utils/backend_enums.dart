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
}
