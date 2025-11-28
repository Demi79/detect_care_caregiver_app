import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_quota_service.dart';

class CameraQuotaBanner extends StatelessWidget {
  final CameraQuotaValidationResult? quotaValidation;
  final VoidCallback? onUpgradePressed;

  const CameraQuotaBanner({
    super.key,
    this.quotaValidation,
    this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    if (quotaValidation == null) return const SizedBox.shrink();

    final validation = quotaValidation!;

    if (!validation.shouldWarn && !validation.shouldUpgrade) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: validation.shouldUpgrade
            ? Colors.red.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: validation.shouldUpgrade
              ? Colors.red.shade200
              : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            validation.shouldUpgrade
                ? Icons.warning_amber_rounded
                : Icons.info_outline,
            color: validation.shouldUpgrade
                ? Colors.red.shade600
                : Colors.orange.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  validation.shouldUpgrade
                      ? 'Đã đạt giới hạn camera'
                      : 'Sắp đạt giới hạn camera',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: validation.shouldUpgrade
                        ? Colors.red.shade800
                        : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  validation.message ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: validation.shouldUpgrade
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (validation.shouldUpgrade && onUpgradePressed != null)
            ElevatedButton(
              onPressed: onUpgradePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Nâng cấp'),
            ),
        ],
      ),
    );
  }
}
