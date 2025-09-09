import 'package:detect_care_caregiver_app/core/config/app_config.dart';

class SettingsEndpoints {
  final String base;
  SettingsEndpoints([String? overrideBase])
    : base = overrideBase ?? AppConfig.apiBaseUrl;

  Uri getSettings() => Uri.parse('$base/system/settings');
  Uri updateSettings(String key) => Uri.parse('$base/system/settings/$key');
}
