class CameraQuotaService {
  CameraQuotaService();

  Future<int> getCurrentCameraQuota() async {
    return 5;
  }

  Future<CameraQuotaValidationResult> canAddCamera(
    int currentCameraCount,
  ) async {
    final quota = await getCurrentCameraQuota();

    if (currentCameraCount >= quota) {
      return CameraQuotaValidationResult(
        canAdd: false,
        message: 'Đã đạt giới hạn $quota camera.',
        quota: quota,
        currentCount: currentCameraCount,
        shouldWarn: false,
      );
    }

    if (currentCameraCount >= (quota * 0.8).floor()) {
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

  CameraQuotaValidationResult({
    required this.canAdd,
    this.message,
    required this.quota,
    required this.currentCount,
    this.shouldWarn = false,
  });

  bool get isNearLimit => currentCount >= (quota * 0.8).floor();
  bool get isAtLimit => currentCount >= quota;
}
