import 'package:flutter/foundation.dart';

import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/subscription/data/service_package_api.dart';
import 'package:detect_care_caregiver_app/features/subscription/stores/subscription_store.dart';

class CameraQuotaService {
  final ServicePackageApi _servicePackageApi;

  CameraQuotaService(this._servicePackageApi);

  /// Lấy camera quota hiện tại của user
  Future<int> getCurrentCameraQuota() async {
    try {
      final token = await AuthStorage.getAccessToken();
      debugPrint(
        '🔐 [CameraQuota] Access token: ${token != null ? 'Found' : 'Not found'}',
      );
      if (token == null) return 0;

      // Ưu tiên gọi endpoint chuyên biệt cung cấp quota nếu backend hỗ trợ.
      // Backend có endpoint GET /users/{userId}/quota (qua
      // ServicePackageApi.getCurrentQuota()) trả về object quota đã chuẩn hóa
      // (ví dụ: camera_quota, retention_days, ...). Đây là nguồn dữ liệu
      // đáng tin cậy hơn so với việc phân tích trực tiếp cấu trúc plan/subs
      // vì các response của subscription có thể thay đổi theo phiên bản API.
      try {
        final quotaPayload = await _servicePackageApi.getCurrentQuota();
        if (quotaPayload != null) {
          debugPrint(
            '📋 [CameraQuota] Quota payload from /users/:id/quota: $quotaPayload',
          );
          final raw =
              quotaPayload['camera_quota'] ?? quotaPayload['cameraQuota'];
          if (raw is int) return raw;
          if (raw is String) {
            final parsed = int.tryParse(raw) ?? 0;
            if (parsed > 0) return parsed;
          }
          // Nếu endpoint quota trả về nhưng thiếu trường `camera_quota`,
          // tiếp tục fallback xuống phần phân tích plan/subscription phía dưới.
          debugPrint(
            '⚠️ [CameraQuota] quota endpoint returned but camera_quota missing',
          );
        }
      } catch (e) {
        debugPrint('⚠️ [CameraQuota] Error calling getCurrentQuota(): $e');
        // swallow and fallback to subscription plan parsing
      }

      // Nếu không lấy được quota từ endpoint chuyên biệt, cố dùng cache
      // trong `SubscriptionStore.instance.planData` (đã được refresh gần đây)
      // để tránh gọi API nhiều lần. Nếu cache chưa có thì gọi
      // ServicePackageApi.getCurrentSubscription() để load dữ liệu subscription.
      var planData = SubscriptionStore.instance.planData;
      planData ??= await _servicePackageApi.getCurrentSubscription();

      // Trích object plan từ payload trả về bởi getCurrentSubscription().
      // Backend có thể trả về nhiều dạng khác nhau; cần hỗ trợ những dạng
      // phổ biến để tìm đúng map chứa `camera_quota`.
      // Các dạng thường gặp:
      //  - { 'plan': {...}, 'subscription': {...} }
      //  - { 'subscriptions': [ { 'plans': {...} } ] }
      //  - trực tiếp: plan map chứa `camera_quota` ở gốc
      Map<String, dynamic>? actualPlanData;
      if (planData != null) {
        // Hàm helper dùng để trích object "plan" từ nhiều dạng payload
        // khác nhau mà backend/ServicePackageApi có thể trả về. Mục tiêu là
        // luôn tìm được map chứa thông tin plan (bao gồm trường `camera_quota`)
        // để client có thể đọc quota chính xác.
        // Những dạng phổ biến:
        //  - normalized: { 'plan': {...}, 'subscription': {...} }
        //  - legacy: { 'subscriptions': [ { 'plans': {...} } ] }
        //  - trực tiếp: plan map (có thể chứa camera_quota ngay ở gốc)
        Map<String, dynamic>? extractPlan(Map<String, dynamic> pd) {
          // 1) Kiểm tra dạng normalized mới: trả về pd['plan'] nếu có
          if (pd.containsKey('plan') && pd['plan'] is Map) {
            return Map<String, dynamic>.from(pd['plan'] as Map);
          }

          // 2) Kiểm tra dạng legacy với 'subscriptions' (một list)
          //    - thường backend có thể trả subscriptions: [ { plans: {...} } ]
          if (pd['subscriptions'] is List) {
            final subs = pd['subscriptions'] as List;
            if (subs.isNotEmpty) {
              final first = subs[0];
              if (first is Map) {
                // Ưu tiên trường 'plans' bên trong subscription
                if (first.containsKey('plans') && first['plans'] is Map) {
                  return Map<String, dynamic>.from(first['plans'] as Map);
                }
                // fallback: subscription có thể dùng key 'plan'
                if (first.containsKey('plan') && first['plan'] is Map) {
                  return Map<String, dynamic>.from(first['plan'] as Map);
                }
              }
            }
          }

          // 3) Nếu payload bản thân nó giống một plan (chứa camera_quota)
          if (pd.containsKey('camera_quota') || pd.containsKey('cameraQuota')) {
            return Map<String, dynamic>.from(pd);
          }

          // Không tìm được plan trong payload
          return null;
        }

        actualPlanData = extractPlan(planData);
      }

      debugPrint('📋 [CameraQuota] Plan data: $actualPlanData');
      // If plan data is missing, assume a minimal default quota so basic users
      // can still add/manage a camera. This avoids blocking edits when the API
      // doesn't return an exFplicit camera_quota field.
      const defaultQuota = 1;
      if (actualPlanData == null) {
        debugPrint(
          '⚠️ [CameraQuota] Plan data is null - using default quota $defaultQuota',
        );
        return defaultQuota;
      }

      // Extract camera quota directly from the plan data
      final cameraQuota = actualPlanData['camera_quota'];
      debugPrint('📦 [CameraQuota] Camera quota from API: $cameraQuota');

      if (cameraQuota is int) {
        debugPrint('🎯 [CameraQuota] Final camera quota: $cameraQuota');
        return cameraQuota;
      } else if (cameraQuota is String) {
        final parsedQuota = int.tryParse(cameraQuota) ?? 0;
        debugPrint('🎯 [CameraQuota] Parsed camera quota: $parsedQuota');
        return parsedQuota > 0 ? parsedQuota : defaultQuota;
      } else {
        debugPrint(
          '❌ [CameraQuota] Invalid or missing camera_quota: $cameraQuota - using default $defaultQuota',
        );
        return defaultQuota;
      }
    } catch (e) {
      debugPrint('❌ [CameraQuota] Error getting camera quota: $e');
      // Error getting camera quota - silently fail in production
      return 0; // Default to 0 if error
    }
  }

  /// Kiểm tra xem có thể thêm camera mới không
  Future<CameraQuotaValidationResult> canAddCamera(
    int currentCameraCount,
  ) async {
    final quota = await getCurrentCameraQuota();

    if (quota == 0) {
      return CameraQuotaValidationResult(
        canAdd: false,
        message: 'Không thể xác định giới hạn camera. Vui lòng liên hệ hỗ trợ.',
        quota: 0,
        currentCount: currentCameraCount,
      );
    }

    if (currentCameraCount >= quota) {
      return CameraQuotaValidationResult(
        canAdd: false,
        message:
            'Đã đạt giới hạn $quota camera. Vui lòng nâng cấp gói dịch vụ.',
        quota: quota,
        currentCount: currentCameraCount,
        shouldUpgrade: true,
      );
    }

    if (currentCameraCount >= quota * 0.8) {
      // Cảnh báo khi đạt 80% quota
      return CameraQuotaValidationResult(
        canAdd: true,
        message:
            'Đã sử dụng $currentCameraCount/$quota camera. Sắp đạt giới hạn.',
        quota: quota,
        currentCount: currentCameraCount,
        shouldWarn: true,
      );
    }

    return CameraQuotaValidationResult(
      canAdd: true,
      quota: quota,
      currentCount: currentCameraCount,
    );
  }
}

class CameraQuotaValidationResult {
  final bool canAdd;
  final String? message;
  final int quota;
  final int currentCount;
  final bool shouldWarn;
  final bool shouldUpgrade;

  CameraQuotaValidationResult({
    required this.canAdd,
    this.message,
    required this.quota,
    required this.currentCount,
    this.shouldWarn = false,
    this.shouldUpgrade = false,
  });

  bool get isNearLimit => currentCount >= quota * 0.8;
  bool get isAtLimit => currentCount >= quota;
}
