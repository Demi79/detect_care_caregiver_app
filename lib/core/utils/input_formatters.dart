import 'package:flutter/services.dart';

/// Input formatters for controlling what users can type
class InputFormatters {
  /// Only allows digits (0-9)
  static final digitsOnly = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));

  /// Only allows digits with one decimal point
  static final decimalOnly = FilteringTextInputFormatter.allow(
    RegExp(r'^\d+\.?\d*$'),
  );

  /// Only allows alphanumeric characters (A-Z, a-z, 0-9)
  static final alphanumericOnly = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z0-9]'),
  );

  /// Only allows letters and spaces
  static final lettersAndSpacesOnly = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z\s]'),
  );

  /// Only allows letters, spaces, hyphens, and apostrophes (for names)
  static final nameFormat = FilteringTextInputFormatter.allow(
    RegExp(r"[a-zA-Z\s\-']"),
  );

  /// Only allows valid email characters
  // static final emailFormat = FilteringTextInputFormatter.allow(
  //   RegExp(r'[a-zA-Z0-9.!#$%&'\''*+/=?^_`{|}~@\-]'),
  // );

  /// Only allows phone number characters
  static final phoneFormat = FilteringTextInputFormatter.allow(
    RegExp(r'[\d\s\-\+\(\)]'),
  );

  /// Only allows URL characters
  // static final urlFormat = FilteringTextInputFormatter.allow(
  //   RegExp(r'[a-zA-Z0-9\-._~:/?#\[\]@!$&'\''()*+,;=]'),
  // );

  /// Uppercase formatter
  static final uppercaseFormatter = _UppercaseFormatter();

  /// Lowercase formatter
  static final lowercaseFormatter = _LowercaseFormatter();

  /// Removes leading/trailing spaces
  static final trimFormatter = _TrimFormatter();

  /// Limits text to maximum length
  // static FilteringTextInputFormatter maxLength(int length) {
  //   return LengthLimitingTextInputFormatter(length);
  // }

  /// Port number formatter (1-65535)
  static final portFormatter = _PortFormatter();

  /// IP address formatter
  static final ipAddressFormatter = _IpAddressFormatter();

  /// Vietnamese phone number formatter with spacing
  static final vietnamesePhoneFormatter = _VietnamesePhoneFormatter();

  /// Username formatter (alphanumeric, underscore, hyphen only)
  static final usernameFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z0-9_\-]'),
  );

  /// Decimal formatter that limits to specific decimal places
  static _DecimalPlacesFormatter decimalPlaces(int places) =>
      _DecimalPlacesFormatter(places);
}

/// Uppercase formatter
class _UppercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Lowercase formatter
class _LowercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}

/// Trim spaces formatter
class _TrimFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.trim(),
      selection: newValue.selection,
    );
  }
}

/// Port number formatter (validates 1-65535)
class _PortFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final int? value = int.tryParse(newValue.text);
    if (value == null) {
      return oldValue;
    }

    if (value > 65535) {
      return oldValue.copyWith(text: '65535');
    }

    return newValue;
  }
}

/// IP address formatter
class _IpAddressFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow only digits and dots
    if (!RegExp(r'^[\d.]*$').hasMatch(text)) {
      return oldValue;
    }

    // Don't allow more than 4 segments
    final segments = text.split('.');
    if (segments.length > 4) {
      return oldValue;
    }

    // Validate each segment
    for (final segment in segments) {
      if (segment.isNotEmpty) {
        final value = int.tryParse(segment);
        if (value == null || value > 255) {
          return oldValue;
        }
      }
    }

    return newValue;
  }
}

/// Vietnamese phone number formatter
class _VietnamesePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Remove non-digits
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 11 digits for Vietnamese numbers
    if (digits.length > 11) {
      return oldValue;
    }

    // Format as: XXX XXX XXX XX
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) {
        formatted += ' ';
      }
      formatted += digits[i];
    }

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.fromPosition(
        TextPosition(offset: formatted.length),
      ),
    );
  }
}

/// Decimal places formatter
class _DecimalPlacesFormatter extends TextInputFormatter {
  final int decimalPlaces;

  _DecimalPlacesFormatter(this.decimalPlaces);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow only digits and one decimal point
    if (!RegExp(r'^[\d.]*$').hasMatch(text)) {
      return oldValue;
    }

    // Allow only one decimal point
    if (text.split('.').length > 2) {
      return oldValue;
    }

    // Limit decimal places
    final parts = text.split('.');
    if (parts.length > 1 && parts[1].length > decimalPlaces) {
      return oldValue.copyWith(
        text: '${parts[0]}.${parts[1].substring(0, decimalPlaces)}',
        selection: newValue.selection,
      );
    }

    return newValue;
  }
}

/// Input constraints for TextFormField
class InputConstraints {
  /// No special constraints
  static const none = InputConstraint();

  /// Only required (non-empty)
  static const required = InputConstraint(minLength: 1);

  /// Email constraints
  static final email = InputConstraint(
    minLength: 5,
    maxLength: 254,
    inputType: TextInputType.emailAddress,
  );

  /// Phone constraints
  static final phone = InputConstraint(
    minLength: 10,
    maxLength: 15,
    inputType: TextInputType.phone,
  );

  /// Password constraints
  static final password = InputConstraint(
    minLength: 6,
    maxLength: 128,
    isPassword: true,
  );

  /// URL constraints
  static final url = InputConstraint(
    minLength: 5,
    maxLength: 2048,
    inputType: TextInputType.url,
  );

  /// Port constraints
  static final port = InputConstraint(
    minLength: 1,
    maxLength: 5,
    inputType: TextInputType.number,
  );

  /// IP address constraints
  static final ipAddress = InputConstraint(
    minLength: 7,
    maxLength: 15,
    inputType: TextInputType.number,
  );

  /// Name constraints
  static final name = InputConstraint(minLength: 2, maxLength: 100);

  /// Username constraints
  static final username = InputConstraint(minLength: 3, maxLength: 30);
}

/// Represents input constraints
class InputConstraint {
  final int? minLength;
  final int? maxLength;
  final TextInputType? inputType;
  final bool isPassword;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? customValidator;

  const InputConstraint({
    this.minLength,
    this.maxLength,
    this.inputType,
    this.isPassword = false,
    this.inputFormatters,
    this.customValidator,
  });

  /// Creates a copy with modified fields
  InputConstraint copyWith({
    int? minLength,
    int? maxLength,
    TextInputType? inputType,
    bool? isPassword,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? customValidator,
  }) {
    return InputConstraint(
      minLength: minLength ?? this.minLength,
      maxLength: maxLength ?? this.maxLength,
      inputType: inputType ?? this.inputType,
      isPassword: isPassword ?? this.isPassword,
      inputFormatters: inputFormatters ?? this.inputFormatters,
      customValidator: customValidator ?? this.customValidator,
    );
  }
}
