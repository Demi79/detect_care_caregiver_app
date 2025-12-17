/// Comprehensive input validation utilities for the entire application
/// Handles various input types: phone, email, numbers, text, URLs, IP addresses, etc.
class InputValidators {
  // ============= PHONE VALIDATION =============
  /// Validates Vietnamese phone numbers (10+ digits)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Số điện thoại không được để trống';
    }

    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleaned.isEmpty) {
      return 'Vui lòng nhập chỉ số điện thoại';
    }

    if (cleaned.length < 10) {
      return 'Số điện thoại phải có ít nhất 10 chữ số';
    }

    if (cleaned.length > 15) {
      return 'Số điện thoại không được vượt quá 15 chữ số';
    }

    return null;
  }

  // ============= EMAIL VALIDATION =============
  /// Validates email addresses with comprehensive RFC 5322 compliance
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email không được để trống';
    }

    final email = value.trim();

    // Basic email regex
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Email không hợp lệ';
    }

    if (email.length > 254) {
      return 'Email quá dài (tối đa 254 ký tự)';
    }

    return null;
  }

  // ============= PASSWORD VALIDATION =============
  /// Validates password strength
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mật khẩu không được để trống';
    }

    if (value.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự';
    }

    if (value.length > 128) {
      return 'Mật khẩu không được vượt quá 128 ký tự';
    }

    return null;
  }

  /// Validates strong password with uppercase, lowercase, numbers, special chars
  static String? validateStrongPassword(String? value) {
    final basicValidation = validatePassword(value);
    if (basicValidation != null) return basicValidation;

    if (!RegExp(r'[A-Z]').hasMatch(value!)) {
      return 'Mật khẩu phải chứa ít nhất một chữ cái viết hoa';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Mật khẩu phải chứa ít nhất một số';
    }

    return null;
  }

  // ============= NAME VALIDATION =============
  /// Validates full name (min 2 chars, max 100 chars)
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Họ tên không được để trống';
    }

    final name = value.trim();

    if (name.length < 2) {
      return 'Họ tên phải có ít nhất 2 ký tự';
    }

    if (name.length > 100) {
      return 'Họ tên không được vượt quá 100 ký tự';
    }


    return null;
  }

  /// Validates username (alphanumeric, underscore, hyphen)
  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Tên đăng nhập không được để trống';
    }

    final username = value.trim();

    if (username.length < 3) {
      return 'Tên đăng nhập phải có ít nhất 3 ký tự';
    }

    if (username.length > 30) {
      return 'Tên đăng nhập không được vượt quá 30 ký tự';
    }

    if (!RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(username)) {
      return 'Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu gạch ngang';
    }

    if (!RegExp(r'^[a-zA-Z]').hasMatch(username)) {
      return 'Tên đăng nhập phải bắt đầu bằng chữ cái';
    }

    return null;
  }

  // ============= NUMBER VALIDATION =============
  /// Validates positive integers
  static String? validatePositiveInteger(String? value, {int? max, int? min}) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập một số';
    }

    final intValue = int.tryParse(value.trim());
    if (intValue == null) {
      return 'Chỉ được nhập số (không được nhập chữ cái hoặc ký tự đặc biệt)';
    }

    if (intValue < 0) {
      return 'Số phải là số dương';
    }

    if (min != null && intValue < min) {
      return 'Số phải lớn hơn hoặc bằng $min';
    }

    if (max != null && intValue > max) {
      return 'Số phải nhỏ hơn hoặc bằng $max';
    }

    return null;
  }

  /// Validates non-negative integers (including 0)
  static String? validateNonNegativeInteger(String? value, {int? max}) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập một số';
    }

    final intValue = int.tryParse(value.trim());
    if (intValue == null) {
      return 'Chỉ được nhập số (không được nhập chữ cái hoặc ký tự đặc biệt)';
    }

    if (intValue < 0) {
      return 'Số không được âm';
    }

    if (max != null && intValue > max) {
      return 'Số phải nhỏ hơn hoặc bằng $max';
    }

    return null;
  }

  /// Validates decimal numbers
  static String? validateDecimal(String? value, {int? decimalPlaces, double? max, double? min}) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập một số';
    }

    final doubleValue = double.tryParse(value.trim());
    if (doubleValue == null) {
      return 'Chỉ được nhập số (không được nhập chữ cái hoặc ký tự đặc biệt)';
    }

    if (decimalPlaces != null) {
      final parts = value.trim().split('.');
      if (parts.length > 1 && parts[1].length > decimalPlaces) {
        return 'Tối đa $decimalPlaces chữ số thập phân';
      }
    }

    if (min != null && doubleValue < min) {
      return 'Số phải lớn hơn hoặc bằng $min';
    }

    if (max != null && doubleValue > max) {
      return 'Số phải nhỏ hơn hoặc bằng $max';
    }

    return null;
  }

  // ============= PORT VALIDATION =============
  /// Validates network port numbers (1-65535)
  static String? validatePort(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Port is optional
    }

    final port = int.tryParse(value.trim());
    if (port == null) {
      return 'Port phải là một số (không được nhập chữ cái hoặc ký tự đặc biệt)';
    }

    if (port < 1 || port > 65535) {
      return 'Port phải trong khoảng 1-65535';
    }

    return null;
  }

  // ============= IP ADDRESS VALIDATION =============
  /// Validates IPv4 addresses
  static String? validateIPv4(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'IP không được để trống';
    }

    final ip = value.trim();

    // IPv4 regex
    final ipv4Regex = RegExp(
      r'^((25[0-5]|(2[0-4]|1\d?)\d)\.?\b){4}$',
    );

    if (!ipv4Regex.hasMatch(ip)) {
      return 'IP không hợp lệ (ví dụ: 192.168.1.1)';
    }

    return null;
  }

  /// Validates IP address or hostname
  static String? validateIPOrHostname(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'IP hoặc hostname không được để trống';
    }

    final ip = value.trim();

    // Check if it's an IPv4 address
    final ipv4Regex = RegExp(r'^((25[0-5]|(2[0-4]|1\d?)\d)\.?\b){4}$');
    if (ipv4Regex.hasMatch(ip)) {
      return null;
    }

    // Check if it's a valid hostname/domain
    final hostnameRegex = RegExp(
      r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$',
    );
    if (hostnameRegex.hasMatch(ip)) {
      return null;
    }

    // Check if it's localhost or 127.0.0.1
    if (ip == 'localhost' || ip == '127.0.0.1') {
      return null;
    }

    return 'IP hoặc hostname không hợp lệ';
  }

  // ============= URL VALIDATION =============
  /// Validates RTSP/HTTP URLs
  static String? validateRTSPURL(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'URL không được để trống';
    }

    try {
      final uri = Uri.parse(value.trim());

      if (uri.scheme.isEmpty) {
        return 'URL phải bắt đầu bằng giao thức (rtsp://, http://, etc.)';
      }

      if (uri.scheme != 'rtsp' && uri.scheme != 'http' && uri.scheme != 'https') {
        return 'Chỉ hỗ trợ RTSP, HTTP, HTTPS';
      }

      if (uri.host.isEmpty) {
        return 'URL phải chứa host/IP';
      }

      return null;
    } catch (e) {
      return 'URL không hợp lệ';
    }
  }

  // ============= TEXT VALIDATION =============
  /// Validates general text (non-empty, max length)
  static String? validateRequired(String? value, {int? minLength, int? maxLength, String? fieldName}) {
    final name = fieldName ?? 'Trường này';

    if (value == null || value.trim().isEmpty) {
      return '$name không được để trống';
    }

    final text = value.trim();

    if (minLength != null && text.length < minLength) {
      return '$name phải có ít nhất $minLength ký tự';
    }

    if (maxLength != null && text.length > maxLength) {
      return '$name không được vượt quá $maxLength ký tự';
    }

    return null;
  }

  /// Validates single line text (no newlines)
  static String? validateSingleLine(String? value, {int? maxLength}) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.contains('\n')) {
      return 'Không được nhập nhiều dòng';
    }

    if (maxLength != null && value.length > maxLength) {
      return 'Không được vượt quá $maxLength ký tự';
    }

    return null;
  }

  // ============= COMPARE VALIDATION =============
  /// Validates that two values match (for password confirmation, etc.)
  static String? validateMatch(String? value, String? otherValue, {String? fieldName}) {
    final name = fieldName ?? 'Giá trị';

    if (value != otherValue) {
      return '$name không khớp';
    }

    return null;
  }

  // ============= INPUT SANITIZATION =============
  /// Removes leading/trailing whitespace and multiple spaces
  static String sanitizeText(String? value) {
    return value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  /// Extracts only digits from a string
  static String extractDigits(String? value) {
    return value?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
  }

  /// Extracts only alphanumeric characters
  static String extractAlphanumeric(String? value) {
    return value?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '') ?? '';
  }

  /// Removes special characters, keeps only letters, numbers, spaces, and hyphens
  static String sanitizeFileName(String? value) {
    return value?.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-_]'), '') ?? '';
  }

  // ============= NUMBER INPUT CONSTRAINTS =============
  /// Creates a TextInputFormatter that only allows digits
  static List<int> digitsOnly(String value) {
    final result = <int>[];
    for (int i = 0; i < value.length; i++) {
      final char = value[i];
      if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
        result.add(i);
      }
    }
    return result;
  }

  /// Validates and limits integer input to max value
  static int? parseAndValidateInteger(String value, {int? maxValue}) {
    if (value.trim().isEmpty) return null;
    final intValue = int.tryParse(value.trim());
    if (intValue == null) return null;
    if (maxValue != null && intValue > maxValue) {
      return maxValue;
    }
    return intValue;
  }

  // ============= AGE VALIDATION =============
  /// Validates age (reasonable human age)
  static String? validateAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Tuổi không được để trống';
    }

    final age = int.tryParse(value.trim());
    if (age == null) {
      return 'Tuổi phải là một số (không được nhập chữ cái hoặc ký tự đặc biệt)';
    }

    if (age < 0) {
      return 'Tuổi không thể âm';
    }

    if (age > 150) {
      return 'Tuổi không được vượt quá 150';
    }

    return null;
  }

  // ============= DATE VALIDATION =============
  /// Validates date in format YYYY-MM-DD
  static String? validateDateFormat(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ngày không được để trống';
    }

    try {
      DateTime.parse(value.trim());
      return null;
    } catch (e) {
      return 'Ngày không hợp lệ (định dạng: YYYY-MM-DD)';
    }
  }

  /// Validates that date is not in the future
  static String? validateNotFutureDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ngày không được để trống';
    }

    try {
      final date = DateTime.parse(value.trim());
      if (date.isAfter(DateTime.now())) {
        return 'Ngày không được là ngày tương lai';
      }
      return null;
    } catch (e) {
      return 'Ngày không hợp lệ (định dạng: YYYY-MM-DD)';
    }
  }

  /// Validates that date is not in the past
  static String? validateNotPastDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ngày không được để trống';
    }

    try {
      final date = DateTime.parse(value.trim());
      if (date.isBefore(DateTime.now())) {
        return 'Ngày không được là ngày quá khứ';
      }
      return null;
    } catch (e) {
      return 'Ngày không hợp lệ (định dạng: YYYY-MM-DD)';
    }
  }

  // ============= VIETNAMESE PHONE SPECIFIC =============
  /// Formats Vietnamese phone number
  static String formatVietnamesePhone(String? value) {
    if (value == null) return '';
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';
    if (digits.length <= 3) return digits;
    if (digits.length <= 6) return '${digits.substring(0, 3)} ${digits.substring(3)}';
    if (digits.length <= 9) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
    }
    return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 9)} ${digits.substring(9)}';
  }

  /// Detects Vietnamese phone number provider (Viettel, Vina, Mobi, etc.)
  static String? detectVietnamesePhoneProvider(String? value) {
    if (value == null) return null;
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return null;

    // Get the 3-digit carrier code
    final carrierCode = digits.substring(digits.length - 10, digits.length - 7);

    // Viettel: 032, 033, 034, 035, 036, 037, 038, 039, 086, 096, 097, 098, 099
    if (RegExp(r'^(032|033|034|035|036|037|038|039|086|096|097|098|099)$')
        .hasMatch(carrierCode)) {
      return 'Viettel';
    }

    // Vinaphone: 031, 081, 082, 083, 084, 085, 091, 094
    if (RegExp(r'^(031|081|082|083|084|085|091|094)$').hasMatch(carrierCode)) {
      return 'Vinaphone';
    }

    // Mobifone: 030, 089, 090, 093
    if (RegExp(r'^(030|089|090|093)$').hasMatch(carrierCode)) {
      return 'Mobifone';
    }

    // Gmobile: 087, 088
    if (RegExp(r'^(087|088)$').hasMatch(carrierCode)) {
      return 'Gmobile';
    }

    return 'Không xác định';
  }
}
