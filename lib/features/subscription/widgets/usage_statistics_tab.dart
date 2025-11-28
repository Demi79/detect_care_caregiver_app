import 'package:flutter/material.dart';

class UsageStatisticsTab extends StatefulWidget {
  final Map<String, dynamic>? planUsage;
  final Future<void> Function() onRefresh;

  const UsageStatisticsTab({
    super.key,
    required this.planUsage,
    required this.onRefresh,
  });

  @override
  State<UsageStatisticsTab> createState() => _UsageStatisticsTabState();
}

class _UsageStatisticsTabState extends State<UsageStatisticsTab> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: widget.planUsage == null
          ? const Center(child: CircularProgressIndicator())
          : widget.planUsage!.isEmpty
          ? const Center(child: Text('Không có dữ liệu thống kê'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thống kê sử dụng',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._buildUsageCards(),
                  const SizedBox(height: 24),
                  const Text(
                    'Chi tiết entitlements',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildEntitlementsCard(),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildUsageCards() {
    return [
      _buildUsageCard(
        'Camera',
        widget.planUsage!['cameras_used'] ?? 0,
        widget.planUsage!['cameras_limit'] ?? 0,
      ),
      const SizedBox(height: 12),
      _buildUsageCard(
        'Lưu trữ',
        widget.planUsage!['storage_used'] ?? 0,
        widget.planUsage!['storage_limit'] ?? 0,
      ),
      const SizedBox(height: 12),
      _buildUsageCard(
        'Người dùng',
        widget.planUsage!['users_used'] ?? 0,
        widget.planUsage!['users_limit'] ?? 0,
      ),
    ];
  }

  Widget _buildEntitlementsCard() {
    if (widget.planUsage == null) {
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
              '${widget.planUsage!['cameras_used'] ?? 0} / ${widget.planUsage!['camera_quota'] ?? 0}',
              isOver:
                  (widget.planUsage!['cameras_used'] ?? 0) >=
                  (widget.planUsage!['camera_quota'] ?? 0),
            ),
            _buildEntitlementRow(
              'Lưu trữ (GB)',
              '${widget.planUsage!['storage_used_gb']?.toStringAsFixed(1) ?? '0.0'} / ${widget.planUsage!['storage_size_gb'] ?? 0}',
              isOver:
                  (widget.planUsage!['storage_used_gb'] ?? 0.0) >
                  (widget.planUsage!['storage_size_gb'] ?? 0.0),
            ),
            _buildEntitlementRow(
              'Người dùng',
              '${widget.planUsage!['seats_used'] ?? 0} / ${widget.planUsage!['caregiver_seats'] ?? 0}',
              isOver:
                  (widget.planUsage!['seats_used'] ?? 0) >=
                  (widget.planUsage!['caregiver_seats'] ?? 0),
            ),
            _buildEntitlementRow(
              'Số ngày lưu trữ',
              widget.planUsage!['retention_days'] ?? 'N/A',
            ),
            _buildEntitlementRow(
              'Sites',
              '${widget.planUsage!['sites_used'] ?? 0} / ${widget.planUsage!['sites'] ?? 0}',
              isOver:
                  (widget.planUsage!['sites_used'] ?? 0) >=
                  (widget.planUsage!['sites'] ?? 0),
            ),
            if (widget.planUsage!['plan_info'] != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Thông tin gói:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Tên gói: ${widget.planUsage!['plan_info']['name'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Mã gói: ${widget.planUsage!['plan_info']['code'] ?? 'N/A'}',
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

  Widget _buildUsageCard(String title, int used, int limit) {
    final percentage = _calculateUsagePercentage(used, limit);
    final color = _getUsageColor(percentage);

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

  double _calculateUsagePercentage(int used, int limit) {
    return limit > 0 ? (used / limit) * 100 : 0.0;
  }

  Color _getUsageColor(double percentage) {
    if (percentage > 80) return Colors.red;
    if (percentage > 60) return Colors.orange;
    return Colors.green;
  }
}
