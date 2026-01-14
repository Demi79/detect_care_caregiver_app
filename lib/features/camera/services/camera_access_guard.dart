import 'package:flutter/material.dart';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/screens/phone_login_screen.dart';
import 'package:detect_care_caregiver_app/features/service_package/screens/service_package_screen.dart';
import 'package:detect_care_caregiver_app/features/subscription/data/service_package_api.dart';

/// Lớp phụ trách kiểm tra điều kiện truy cập camera theo từng bước rõ ràng.
class CameraAccessGuard {
  CameraAccessGuard({ServicePackageApi? api})
    : _api = api ?? ServicePackageApi();

  final ServicePackageApi _api;

  Future<bool> ensureSubscriptionAllowed(BuildContext context) async {
    try {
      // Bước 1: Kiểm tra đã có token đăng nhập hay chưa.
      final token = await AuthStorage.getAccessToken();
      if (token == null) {
        if (!context.mounted) return false;
        await _showLoginRequiredDialog(context);
        return false;
      }

      // Bước 2: Lấy thông tin gói từ API và đọc mã gói nếu có.
      final plan = await _api.getCurrentPlan();
      AppLogger.d('🐛 [Camera] plan from getCurrentPlan(): $plan');
      final planCode = _extractPlanCode(plan);
      AppLogger.d('🐛 [Camera] detected plan.code from plan object: $planCode');
      if (planCode != null) return true;

      // Bước 3: Nếu plan null, đọc dữ liệu subscription đã normalize.
      final subscription = await _api.getCurrentSubscription();
      AppLogger.d('🐛 [Camera] subscription object: $subscription');

      final subscriptionPlanCode = _extractPlanCode(subscription);
      AppLogger.d('Current plan code: $subscriptionPlanCode');
      if (subscriptionPlanCode != null) return true;

      // Bước 4: Không tìm thấy gói thì yêu cầu nâng cấp/mua gói.
      if (!context.mounted) return false;
      await _showUpgradeRequiredDialog(context);
      return false;
    } catch (e, st) {
      // Bước 5: Xử lý lỗi chung và cho phép thử lại nếu người dùng muốn.
      AppLogger.e('CameraAccessGuard ensureSubscriptionAllowed error', e, st);
      if (!context.mounted) return false;

      final retry = await _showErrorDialog(context);
      if (retry == true) {
        try {
          final token = await AuthStorage.getAccessToken();
          if (token == null) return false;
          final subscription = await _api.getCurrentSubscription();
          final planCode = _extractPlanCode(subscription);
          return planCode != null;
        } catch (err, retrySt) {
          AppLogger.e('CameraAccessGuard retry failed', err, retrySt);
          return false;
        }
      }
      return false;
    }
  }

  Future<void> _showLoginRequiredDialog(BuildContext context) async {
    // Hiển thị dialog hướng dẫn người dùng đăng nhập trước khi kiểm tra gói.
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yêu cầu đăng nhập'),
        content: const Text(
          'Bạn cần đăng nhập để kiểm tra quyền truy cập camera.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
              );
            },
            child: const Text('Đăng nhập'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpgradeRequiredDialog(BuildContext context) async {
    // Thông báo khi không có gói phù hợp và gợi ý nâng cấp/mua gói.
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Không có quyền truy cập'),
        content: const Text(
          'Tính năng Camera yêu cầu gói trả phí. Vui lòng nâng cấp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ServicePackageScreen()),
              );
            },
            child: const Text('Mua gói'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showErrorDialog(BuildContext context) {
    // Cho phép người dùng chọn Huỷ/Thử lại/Mua gói khi gặp lỗi hệ thống.
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Lỗi kiểm tra gói'),
        content: const Text(
          'Không thể kiểm tra gói dịch vụ tại thời điểm này. Vui lòng thử lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Thử lại'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ServicePackageScreen()),
              );
            },
            child: const Text('Mua gói'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    // Đồng nhất mọi object về Map<String, dynamic> để thao tác tiện lợi.
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  String? _extractPlanCode(dynamic payload) {
    // Bóc tách mã gói từ các dạng cấu trúc trả về khác nhau.
    final map = _asMap(payload);
    if (map == null) return null;

    String? readPlanCode(Map<String, dynamic>? source) {
      if (source == null) return null;
      final raw = source['plan_code'] ?? source['code'];
      if (raw == null) return null;
      final value = raw.toString().trim();
      return value.isEmpty ? null : value;
    }

    return readPlanCode(_asMap(map['plan'])) ??
        readPlanCode(_asMap(map['subscription'])) ??
        readPlanCode(map);
  }
}
