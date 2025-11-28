import 'package:flutter/material.dart';

class EntitlementsCard extends StatelessWidget {
  final Map<String, dynamic>? planUsage;

  const EntitlementsCard({super.key, required this.planUsage});

  @override
  Widget build(BuildContext context) {
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
            _buildEntitlementRow(
              'Camera',
              '${planUsage!['cameras_used'] ?? 0} / ${planUsage!['camera_quota'] ?? 0}',
              isOver:
                  (planUsage!['cameras_used'] ?? 0) >=
                  (planUsage!['camera_quota'] ?? 0),
            ),
            _buildEntitlementRow(
              'Lưu trữ (GB)',
              '${(planUsage!['storage_used_gb'] ?? 0.0).toString()} / ${planUsage!['storage_size_gb'] ?? 0}',
              isOver:
                  (planUsage!['storage_used_gb'] ?? 0.0) >
                  (planUsage!['storage_size_gb'] ?? 0.0),
            ),
            _buildEntitlementRow(
              'Người dùng',
              '${planUsage!['seats_used'] ?? 0} / ${planUsage!['caregiver_seats'] ?? 0}',
              isOver:
                  (planUsage!['seats_used'] ?? 0) >=
                  (planUsage!['caregiver_seats'] ?? 0),
            ),
            _buildEntitlementRow(
              'Số ngày lưu trữ',
              planUsage!['retention_days'] ?? 'N/A',
            ),
            _buildEntitlementRow(
              'Sites',
              '${planUsage!['sites_used'] ?? 0} / ${planUsage!['sites'] ?? 0}',
              isOver:
                  (planUsage!['sites_used'] ?? 0) >= (planUsage!['sites'] ?? 0),
            ),
            if (planUsage!['plan_info'] != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Thông tin gói:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Tên gói: ${planUsage!['plan_info']['name'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Mã gói: ${planUsage!['plan_info']['code'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEntitlementRow(
    String label,
    dynamic value, {
    bool isOver = false,
  }) {
    final text = value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
