class PhoneUtils {
  /// Format Vietnamese phone number to international format (84xxxxxxxxx)
  /// Handles various input formats:
  /// - 0823944945 -> 84823944945
  /// - +84823944945 -> 84823944945
  /// - 00823944945 -> 84823944945
  /// - 84823944945 -> 84823944945
  static String formatVietnamesePhone(String phone) {
    if (phone.isEmpty) return phone;

    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');

    if (cleaned.startsWith('00')) {
      // International format with 00 prefix
      return '84${cleaned.substring(2)}';
    } else if (cleaned.startsWith('84') && cleaned.length == 11) {
      // Already in correct format
      return cleaned;
    } else if (cleaned.startsWith('+84')) {
      // International format with + prefix
      return '84${cleaned.substring(3)}';
    } else if (cleaned.startsWith('0') && cleaned.length == 10) {
      // Local format starting with 0
      return '84${cleaned.substring(1)}';
    } else if (cleaned.length == 9) {
      // Just the number without country code
      return '84$cleaned';
    } else {
      // Fallback: if doesn't match any pattern, assume it's already formatted or add 84
      if (!cleaned.startsWith('84')) {
        return '84$cleaned';
      }
      return cleaned;
    }
  }

  /// Format Vietnamese phone number to Firebase E.164 format (+84xxxxxxxxx)
  /// Firebase Authentication requires E.164 format with + prefix
  /// - 0823944945 -> +84823944945
  /// - 84823944945 -> +84823944945
  /// - +84823944945 -> +84823944945
  static String formatForFirebase(String phone) {
    if (phone.isEmpty) return phone;

    // First format to 84xxxxxxxxx
    String formatted = formatVietnamesePhone(phone);

    // Then add + prefix for Firebase E.164 format
    if (formatted.startsWith('84')) {
      return '+$formatted';
    }

    // Fallback: if somehow doesn't start with 84, add it
    return '+84$formatted';
  }

  /// Validate if phone number is in valid Vietnamese format
  static bool isValidVietnamesePhone(String phone) {
    if (phone.isEmpty) return false;

    String cleaned = phone.replaceAll(RegExp(r'\D'), '');

    // Check for valid lengths and formats
    if (cleaned.startsWith('84') && cleaned.length == 11) {
      return true; // 84xxxxxxxxx
    } else if (cleaned.startsWith('0') && cleaned.length == 10) {
      return true; // 0xxxxxxxxx
    } else if (cleaned.length == 9) {
      return true; // xxxxxxxxx
    }

    return false;
  }
}
