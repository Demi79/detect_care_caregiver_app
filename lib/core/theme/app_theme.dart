import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF236AFE);
  static const Color primaryBlueDark = Color(0xFF1850CC);
  static const Color primaryBlueLight = Color(0xFF4A8AFF);
  static const Color background = Color(0xFFF5F5F5);

  // Alternate/Legacy Brand Colors (used by some screens)
  static const Color brandBlueAlt = Color(0xFF2E7BF0);
  static const Color brandBlueAltDark = Color(0xFF1E40AF);

  // Header/Text specific brand shades
  static const Color headerBlue = Color(0xFF1E3A8A);
  static const Color textSecondaryAlt = Color(0xFF374151);
  static const Color textMutedAlt = Color(0xFF64748B);

  // Accents
  static const Color accentGreen = Color(0xFF10B981);

  // Healthcare Specific Colors
  static const Color warningColor = Color(0xFFFF6B35);
  static const Color warningColorLight = Color(0xFFFF8F66);
  static const Color warningColorDark = Color(0xFFE55A2B);

  static const Color activityColor = Color(0xFF4CAF50);
  static const Color activityColorLight = Color(0xFF6FBF73);
  static const Color activityColorDark = Color(0xFF3E8E41);

  static const Color reportColor = Color(0xFF9C27B0);
  static const Color reportColorLight = Color(0xFFB854C7);
  static const Color reportColorDark = Color(0xFF7B1FA2);

  static const Color dangerColor = Color(0xFFE53E3E);
  static const Color dangerColorLight = Color(0xFFFC8181);
  static const Color dangerColorDark = Color(0xFFC53030);

  static const Color successColor = Color(0xFF38A169);
  static const Color successColorLight = Color(0xFF68D391);
  static const Color successColorDark = Color(0xFF2F855A);

  // Background Colors
  static const Color scaffoldBackground = Color(0xFFF8FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surfaceBackground = Color(0xFFF1F5F9);

  // Screen-specific Backgrounds
  static const Color loginBgTop = Color(0xFFF8FBFF);
  static const Color loginBgBottom = Color(0xFFF0F7FF);

  // Text Colors
  static const Color text = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textMuted = Color(0xFF718096);

  // Component Colors
  static const Color selectedTextColor = Color(0xFFFFFFFF);
  static const Color unselectedTextColor = Color(0xFF6B7280);
  static const Color unselectedBgColor = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color dividerColor = Color(0xFFEDF2F7);
  static const Color dividerGrayAlt = Color(0xFFE5E7EB);

  // Inputs
  static const Color inputBorder = Color(0xFFD1D5DB);
  static const Color inputBg = Color(0xFFFAFBFC);
  static const Color mutedGray = Color(0xFF9CA3AF);

  // Shadow and Elevation
  static const Color shadowColor = Color(0x1A000000);
  static const Color shadowColorLight = Color(0x0A000000);
  static const Color shadowColorMedium = Color(0x14000000);

  // Status Colors with Semantic Meaning
  static const Map<String, Color> statusColors = {
    'critical': dangerColor,
    'warning': warningColor,
    'normal': successColor,
    'info': primaryBlue,
    'danger': dangerColor,
  };

  // Gradient Definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, primaryBlueDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [warningColor, warningColorDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [activityColor, activityColorDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Common Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: shadowColor, blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: shadowColorMedium, blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> floatingShadow = [
    BoxShadow(color: shadowColor, blurRadius: 16, offset: Offset(0, 8)),
  ];

  // Border Radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXL = 20.0;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;

  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: primaryBlue,
        secondary: activityColor,
        tertiary: reportColor,
        surface: cardBackground,
        error: dangerColor,
      ),
      useMaterial3: true,
      fontFamily: 'SF Pro Text', // iOS-like font
      scaffoldBackgroundColor: scaffoldBackground,

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: cardBackground,
        elevation: 0,
        scrolledUnderElevation: 4,
        shadowColor: shadowColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: text, size: 24),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shadowColor: shadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingL,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: selectedTextColor,
          elevation: 0,
          shadowColor: primaryBlue.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(
            vertical: spacingL,
            horizontal: spacingXXL,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusLarge),
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: text, size: 24),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: -0.8,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: -0.6,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: -0.4,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: 0.1,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: 0.1,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: text,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textMuted,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: text,
          letterSpacing: 1.25,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: text,
          letterSpacing: 1.5,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textMuted,
          letterSpacing: 1.5,
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Utility methods for getting colors
  static Color getStatusColor(String status) {
    return statusColors[status] ?? primaryBlue;
  }

  static Color getStatusColorLight(String status) {
    switch (status.toLowerCase()) {
      case 'danger':
      case 'critical':
        return const Color.fromARGB(255, 208, 32, 32);
      case 'warning':
        return const Color.fromARGB(255, 207, 145, 51);
      case 'normal':
      case 'success':
        return activityColorLight;
      default:
        return primaryBlueLight;
    }
  }
}
