import 'package:detect_care_caregiver_app/features/setting/models/settings_models.dart';
import 'package:detect_care_caregiver_app/features/setting/repositories/settings_repository.dart';
import 'package:flutter/foundation.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository repo;
  String _userId;

  SettingsProvider({required this.repo, required String userId})
    : _userId = userId;

  String get userId => _userId;

  String? _loadedForUserId;

  AppSettings? _settings;
  String? _error;
  bool _loading = false;
  bool _saving = false;

  AppSettings? get settings => _settings;
  String? get error => _error;
  bool get isLoading => _loading;
  bool get isSaving => _saving;

  bool hasLoadedFor(String uid) => _loadedForUserId == uid && _settings != null;

  void updateUserId(String userId, {bool reload = true}) {
    if (userId == _userId) return;

    _userId = userId;

    if (_userId.isEmpty) {
      _settings = null;
      _error = null;
      _loadedForUserId = null;
      notifyListeners();
      return;
    }

    if (reload) {
      load();
    }
  }

  Future<void> load() async {
    if (_userId.isEmpty) return;
    if (_loading) return;

    if (_loadedForUserId == _userId && _settings != null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await repo.getSettings(_userId);
      _loadedForUserId = _userId;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> save(AppSettings newSettings, {bool patch = true}) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      _settings = await repo.updateSettings(_userId, newSettings, patch: patch);
    } catch (e) {
      _error = e.toString();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void setNotification(NotificationSettings n) {
    if (_settings == null) return;
    _settings = _settings!.copyWith(notification: n);
    notifyListeners();
  }

  void setImage(ImageSettings i) {
    if (_settings == null) return;
    _settings = _settings!.copyWith(image: i);
    notifyListeners();
  }

  void setContacts(List<EmergencyContact> list) {
    if (_settings == null) return;
    _settings = _settings!.copyWith(contacts: List.of(list));
    notifyListeners();
  }
}
