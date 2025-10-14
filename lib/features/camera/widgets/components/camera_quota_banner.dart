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

    if (!validation.shouldWarn) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade600, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sắp đạt giới hạn camera',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  validation.message ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
