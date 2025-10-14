class RoleUtils {
  static String convertRole(String role) {
    switch (role) {
      case 'customer':
        return 'Khách hàng';
      case 'admin':
        return 'Quản trị viên';
      case 'doctor':
        return 'Bác sĩ';
      case 'nurse':
        return 'Y tá';
      case 'caregiver':
        return 'Người chăm sóc';
      default:
        return 'Không xác định';
    }
  }
}
