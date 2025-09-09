import 'package:detect_care_caregiver_app/features/setting/data/image_settings_remote_data_source.dart';
import 'package:flutter/material.dart';

class ImageSettingsProvider with ChangeNotifier {
  final ImageSettingsRemoteDataSource remoteDataSource;

  ImageSettingsProvider(this.remoteDataSource);

  List<ImageSetting> _settings = [];
  bool _loading = false;

  List<ImageSetting> get settings => _settings;
  bool get loading => _loading;

  Future<void> loadSettings() async {
    _loading = true;
    notifyListeners();
    try {
      _settings = await remoteDataSource.fetchSettings();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateSetting(String key, String value) async {
    await remoteDataSource.updateSetting(key, value);
    await loadSettings();
  }

  Future<void> toggleSetting(String key, bool enabled) async {
    await remoteDataSource.toggleSetting(key, enabled);
    await loadSettings();
  }
}
