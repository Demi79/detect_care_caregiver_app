import 'package:detect_care_caregiver_app/features/setting/models/settings_models.dart';

abstract class SettingsRepository {
  Future<AppSettings> getSettings(String userId);
  Future<AppSettings> updateSettings(
    String userId,
    AppSettings settings, {
    bool patch,
  });
}
