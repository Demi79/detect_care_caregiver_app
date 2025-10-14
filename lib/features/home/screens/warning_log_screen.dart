import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/home/widgets/filter_bar.dart';
import 'package:flutter/material.dart';

import '../constants/filter_constants.dart';
import '../widgets/action_log_card.dart';

class WarningLogScreen extends StatelessWidget {
  final List<LogEntry> logs;

  final DateTimeRange? selectedDayRange;

  final String selectedStatus;
  final String selectedPeriod;

  final ValueChanged<DateTimeRange?> onDayRangeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPeriodChanged;
  final void Function(String eventId, {bool? confirmed})? onEventUpdated;

  const WarningLogScreen({
    super.key,
    required this.logs,
    required this.selectedDayRange,
    required this.selectedStatus,
    required this.selectedPeriod,
    required this.onDayRangeChanged,
    required this.onStatusChanged,
    required this.onPeriodChanged,
    this.onEventUpdated,
  });

  static void _noop(String? _) {}
  static void _noopDay(DateTimeRange? _) {}

  WarningLogScreen.defaultScreen({Key? key})
    : this(
        key: key,
        logs: const [],
        selectedDayRange: HomeFilters.defaultDayRange,
        selectedStatus: HomeFilters.defaultStatus,
        selectedPeriod: HomeFilters.defaultPeriod,
        onDayRangeChanged: _noopDay,
        onStatusChanged: _noop,
        onPeriodChanged: _noop,
        onEventUpdated: null,
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FilterBar(
            statusOptions: HomeFilters.statusOptions,
            periodOptions: HomeFilters.periodOptions,
            selectedDayRange: selectedDayRange,
            selectedStatus: selectedStatus,
            selectedPeriod: selectedPeriod,
            onDayRangeChanged: onDayRangeChanged,
            onStatusChanged: onStatusChanged,
            onPeriodChanged: onPeriodChanged,
          ),

          const SizedBox(height: 24),

          _SummaryRow(logs: logs),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          if (logs.isEmpty)
            const _EmptyState()
          else
            ...logs.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ActionLogCard(
                  data: log,
                  onUpdated: (newStatus, {bool? confirmed}) {
                    try {
                      if (onEventUpdated != null) {
                        onEventUpdated!(log.eventId, confirmed: confirmed);
                      }
                    } catch (_) {}
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.logs});
  final List<LogEntry> logs;

  bool _isCritical(LogEntry e) {
    final t = e.eventType.toLowerCase();
    return t == 'fall' ||
        t == 'fall_detection' ||
        t == 'abnormal_behavior' ||
        t == 'visitor_detected';
  }

  @override
  Widget build(BuildContext context) {
    final int total = logs.length;
    final int critical = logs.where(_isCritical).length;
    final int others = (total - critical).clamp(0, total);

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Cảnh báo nghiêm trọng',
            value: '$critical',
            icon: Icons.emergency_rounded,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'Tổng ghi nhật ký',
            value: '$total',
            icon: Icons.list_alt_rounded,
            color: AppTheme.reportColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'Sự kiện khác',
            value: '$others',
            icon: Icons.monitor_heart_rounded,
            color: AppTheme.activityColor,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.unselectedTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppTheme.unselectedTextColor,
          ),
          const SizedBox(height: 20),
          Text(
            'Không tìm thấy kết quả',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thử thay đổi từ khóa hoặc bộ lọc',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.unselectedTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
