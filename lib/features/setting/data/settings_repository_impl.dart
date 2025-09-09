import 'package:detect_care_caregiver_app/features/setting/repositories/settings_repository.dart';

import '../models/settings_models.dart';
import 'settings_remote_data_source.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsRemoteDataSource remote;
  SettingsRepositoryImpl(this.remote);

  @override
  Future<AppSettings> getSettings(String userId) => remote.fetchSettings();

  @override
  Future<AppSettings> updateSettings(
    String key,
    AppSettings settings, {
    bool patch = true,
  }) => remote.updateSettings(key, settings, patch: patch);
}
