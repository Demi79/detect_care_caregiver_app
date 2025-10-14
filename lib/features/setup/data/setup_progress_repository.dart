import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/setup_step.dart';
import '../models/setup_progress.dart';

class SetupProgressRepository {
  static const String _setupProgressKey = 'household_setup_progress';
  static const String _isFirstTimeUserKey = 'is_first_time_user';

  Future<SetupProgress> getSetupProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressJson = prefs.getString(_setupProgressKey);

      if (progressJson == null) {
        return _createDefaultSetupProgress();
      }

      final Map<String, dynamic> data = json.decode(progressJson);
      return SetupProgress.fromJson(data);
    } catch (e) {
      return _createDefaultSetupProgress();
    }
  }

  Future<void> saveSetupProgress(SetupProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressJson = json.encode(progress.toJson());
      await prefs.setString(_setupProgressKey, progressJson);
    } catch (e) {
      debugPrint('Error saving setup progress: $e');
    }
  }

  Future<bool> isFirstTimeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isFirstTimeUserKey) ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<void> setFirstTimeUser(bool isFirstTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isFirstTimeUserKey, isFirstTime);
    } catch (e) {
      debugPrint('Error setting first time user flag: $e');
    }
  }

  Future<void> clearSetupProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_setupProgressKey);
      await prefs.remove(_isFirstTimeUserKey);
    } catch (e) {
      debugPrint('Error clearing setup progress: $e');
    }
  }

  SetupProgress _createDefaultSetupProgress() {
    return SetupProgress(
      steps: [
        const SetupStep(
          type: SetupStepType.welcome,
          title: 'Chào mừng',
          description: 'Thiết lập ứng dụng chăm sóc sức khỏe',
          order: 0,
          isSkippable: false,
        ),
        const SetupStep(
          type: SetupStepType.patientProfile,
          title: 'Thông tin bệnh nhân',
          description: 'Thiết lập hồ sơ bệnh nhân cần chăm sóc',
          order: 1,
          isSkippable: false,
        ),
        const SetupStep(
          type: SetupStepType.imageSettings,
          title: 'Cài đặt hình ảnh',
          description: 'Cấu hình chất lượng và lưu trữ hình ảnh',
          order: 2,
          isSkippable: true,
        ),
        const SetupStep(
          type: SetupStepType.alertSettings,
          title: 'Cài đặt thông báo',
          description: 'Thiết lập cách thức nhận thông báo khẩn cấp',
          order: 3,
          isSkippable: true,
        ),
        const SetupStep(
          type: SetupStepType.caregiverSetup,
          title: 'Người chăm sóc',
          description: 'Thêm và mời người chăm sóc',
          order: 4,
          isSkippable: true,
        ),
        const SetupStep(
          type: SetupStepType.completion,
          title: 'Hoàn tất',
          description: 'Thiết lập hoàn tất, sẵn sàng sử dụng',
          order: 5,
          isSkippable: false,
        ),
      ],
      currentStepIndex: 0,
      isSetupCompleted: false,
      lastUpdated: DateTime.now(),
    );
  }
}
