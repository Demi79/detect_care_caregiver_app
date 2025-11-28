import 'package:flutter/material.dart';

/// Utility class for usage statistics UI components and calculations
class UsageUtils {
  /// Builds a list of usage cards for different resource types
  static List<Widget> buildUsageCards(Map<String, dynamic> planUsage) {
    return [
      buildUsageCard(
        'Camera',
        planUsage['cameras_used'] ?? 0,
        planUsage['cameras_limit'] ?? 0,
      ),
      const SizedBox(height: 12),
      buildUsageCard(
        'Lưu trữ',
        planUsage['storage_used'] ?? 0,
        planUsage['storage_limit'] ?? 0,
      ),
      const SizedBox(height: 12),
      buildUsageCard(
        'Người dùng',
        planUsage['users_used'] ?? 0,
        planUsage['users_limit'] ?? 0,
      ),
    ];
  }

  /// Builds an entitlements card showing plan benefits and usage
  static Widget buildEntitlementsCard(Map<String, dynamic>? planUsage) {
    if (planUsage == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Đang tải quyền lợi...'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quyền lợi gói dịch vụ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            buildEntitlementRow(
              'Camera',
              '${planUsage['cameras_used'] ?? 0} / ${planUsage['camera_quota'] ?? 0}',
              isOver:
                  (planUsage['cameras_used'] ?? 0) >=
                  (planUsage['camera_quota'] ?? 0),
            ),
            buildEntitlementRow(
              'Lưu trữ (GB)',
              '${planUsage['storage_used_gb']?.toStringAsFixed(1) ?? '0.0'} / ${planUsage['storage_size_gb'] ?? 0}',
              isOver:
                  (planUsage['storage_used_gb'] ?? 0.0) >
                  (planUsage['storage_size_gb'] ?? 0.0),
            ),
            buildEntitlementRow(
              'Người dùng',
              '${planUsage['seats_used'] ?? 0} / ${planUsage['caregiver_seats'] ?? 0}',
              isOver:
                  (planUsage['seats_used'] ?? 0) >=
                  (planUsage['caregiver_seats'] ?? 0),
            ),
            buildEntitlementRow(
              'Số ngày lưu trữ',
              planUsage['retention_days'] ?? 'N/A',
            ),
            buildEntitlementRow(
              'Sites',
              '${planUsage['sites_used'] ?? 0} / ${planUsage['sites'] ?? 0}',
              isOver:
                  (planUsage['sites_used'] ?? 0) >= (planUsage['sites'] ?? 0),
            ),
            if (planUsage['plan_info'] != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Thông tin gói:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Tên gói: ${planUsage['plan_info']['name'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Mã gói: ${planUsage['plan_info']['code'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds a single entitlement row
  static Widget buildEntitlementRow(
    String label,
    dynamic value, {
    bool isOver = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// Builds a usage card for a specific resource type
  static Widget buildUsageCard(String title, int used, int limit) {
    final percentage = calculateUsagePercentage(used, limit);
    final color = getUsageColor(percentage);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$used / $limit'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: limit > 0 ? used / limit : 0,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 4),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculates usage percentage
  static double calculateUsagePercentage(int used, int limit) {
    return limit > 0 ? (used / limit) * 100 : 0.0;
  }

  /// Gets color based on usage percentage
  static Color getUsageColor(double percentage) {
    if (percentage > 80) return Colors.red;
    if (percentage > 60) return Colors.orange;
    return Colors.green;
  }
}
