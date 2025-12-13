import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/home/widgets/filter_bar.dart';
import 'package:flutter/material.dart';

import '../constants/filter_constants.dart';
import '../widgets/action_log_card.dart';

class HighConfidenceEventsScreen extends StatelessWidget {
  final List<LogEntry> logs;
  final DateTimeRange? selectedDayRange;
  final String selectedStatus;
  final String selectedPeriod;

  final ValueChanged<DateTimeRange?> onDayRangeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPeriodChanged;
  final VoidCallback? onRefresh;
  final void Function(String eventId, {bool? confirmed})? onEventUpdated;

  const HighConfidenceEventsScreen({
    super.key,
    required this.logs,
    required this.selectedDayRange,
    required this.selectedStatus,
    required this.selectedPeriod,
    required this.onDayRangeChanged,
    required this.onStatusChanged,
    required this.onPeriodChanged,
    this.onRefresh,
    this.onEventUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = logs.where((log) {
      try {
        final ls = log.lifecycleState?.toString().toLowerCase();
        if (ls != null && ls == 'canceled') return false;
      } catch (_) {}
      try {
        if (log.status.toString().toLowerCase() == 'unknowns') return false;
      } catch (_) {}
      try {
        if (log.status.toString().toLowerCase() == 'suspect') return false;
      } catch (_) {}
      final st = log.status.toLowerCase();
      final selectedSt = selectedStatus.toLowerCase();

      bool statusMatches;
      if (selectedSt == 'abnormal') {
        statusMatches = st == 'danger' || st == 'warning';
      } else if (selectedSt == 'all') {
        statusMatches = true;
      } else {
        statusMatches = st == selectedSt;
      }
      if (!statusMatches) return false;

      final rawDt = log.detectedAt ?? log.createdAt;
      if (rawDt == null) return false;
      final dt = rawDt.toLocal();

      if (selectedDayRange != null) {
        final dateOnly = DateTime(dt.year, dt.month, dt.day);
        final start = DateTime(
          selectedDayRange!.start.year,
          selectedDayRange!.start.month,
          selectedDayRange!.start.day,
        );
        final end = DateTime(
          selectedDayRange!.end.year,
          selectedDayRange!.end.month,
          selectedDayRange!.end.day,
        );
        if (dateOnly.isBefore(start) || dateOnly.isAfter(end)) return false;
      }

      final slot = selectedPeriod.toLowerCase();
      if (slot != 'all' && slot.isNotEmpty) {
        final hour = dt.hour;
        bool inSlot = switch (slot) {
          '00-06' => hour >= 0 && hour < 6,
          '06-12' => hour >= 6 && hour < 12,
          '12-18' => hour >= 12 && hour < 18,
          '18-24' => hour >= 18 && hour < 24,
          'morning' => hour >= 5 && hour < 12,
          'afternoon' => hour >= 12 && hour < 18,
          'evening' => hour >= 18 && hour < 22,
          'night' => hour >= 22 || hour < 5,
          _ => true,
        };
        if (!inSlot) return false;
      }
      return true;
    }).toList();

    // --- UI ---
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FilterBar(
            statusOptions: const [
              'all',
              'abnormal',
              'danger',
              'warning',
              'normal',
            ],
            periodOptions: HomeFilters.periodOptions,
            selectedDayRange: selectedDayRange,
            selectedStatus: selectedStatus,
            selectedPeriod: selectedPeriod,
            onDayRangeChanged: onDayRangeChanged,
            onStatusChanged: onStatusChanged,
            onPeriodChanged: onPeriodChanged,
          ),
          const SizedBox(height: 24),
          _SummaryRow(logs: filtered, selectedStatus: selectedStatus),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Empty or Log list
          if (filtered.isEmpty)
            _EmptyState(
              onClearFilters: () {
                onDayRangeChanged(HomeFilters.defaultDayRange);
                onStatusChanged(HomeFilters.defaultStatus);
                onPeriodChanged(HomeFilters.defaultPeriod);
              },
              onRefresh: onRefresh,
            )
          else
            ...filtered.map((log) {
              try {
                print(
                  '[HighConfidenceEventsScreen] event=${log.eventId} confirm=${log.confirmStatus} status=${log.status} detectedAt=${log.detectedAt}',
                );
              } catch (_) {}
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ActionLogCard(
                  data: log,
                  onUpdated: (newStatus, {bool? confirmed}) =>
                      onEventUpdated?.call(log.eventId, confirmed: confirmed),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.logs, required this.selectedStatus});
  final List<LogEntry> logs;
  final String selectedStatus;

  @override
  Widget build(BuildContext context) {
    final sel = selectedStatus.toLowerCase();

    final int dangerCount = logs.where((e) {
      try {
        return e.status.toString().toLowerCase() == 'danger';
      } catch (_) {
        return false;
      }
    }).length;

    final int warningCount = logs.where((e) {
      try {
        return e.status.toString().toLowerCase() == 'warning';
      } catch (_) {
        return false;
      }
    }).length;

    final int normalCount = logs.where((e) {
      try {
        return e.status.toString().toLowerCase() == 'normal';
      } catch (_) {
        return false;
      }
    }).length;

    final int abnormalCount = dangerCount + warningCount;
    final int total = logs.length;

    late final Widget leftCard;
    late final Widget middleCard;
    late final Widget rightCard;

    if (sel == 'abnormal') {
      leftCard = _SummaryCard(
        title: 'Nguy hiểm',
        value: '$dangerCount',
        icon: Icons.emergency_rounded,
        color: Colors.red,
      );
      middleCard = _SummaryCard(
        title: 'Tổng nhật ký',
        value: '$abnormalCount',
        icon: Icons.list_alt_rounded,
        color: AppTheme.reportColor,
      );
      rightCard = _SummaryCard(
        title: 'Cảnh báo',
        value: '$warningCount',
        icon: Icons.warning_amber_rounded,
        color: const Color.fromARGB(255, 220, 139, 17),
      );
    } else if (sel == 'all') {
      final totalLogged = dangerCount + warningCount + normalCount;
      leftCard = _SummaryCard(
        title: 'Bất thường',
        value: '$abnormalCount',
        icon: Icons.emergency_rounded,
        color: Colors.red,
      );
      middleCard = _SummaryCard(
        title: 'Tổng nhật ký',
        value: '$totalLogged',
        icon: Icons.list_alt_rounded,
        color: AppTheme.reportColor,
      );
      rightCard = _SummaryCard(
        title: 'Bình thường',
        value: '$normalCount',
        icon: Icons.monitor_heart_rounded,
        color: AppTheme.activityColor,
      );
    } else if (sel == 'danger') {
      leftCard = _SummaryCard(
        title: 'Nguy hiểm',
        value: '$dangerCount',
        icon: Icons.emergency_rounded,
        color: Colors.red,
      );
      middleCard = _SummaryCard(
        title: 'Tổng nhật ký',
        value: '$dangerCount',
        icon: Icons.list_alt_rounded,
        color: AppTheme.reportColor,
      );
      rightCard = _SummaryCard(
        title: 'Sự kiện khác',
        value: '0',
        icon: Icons.monitor_heart_rounded,
        color: AppTheme.activityColor,
      );
    } else if (sel == 'warning') {
      leftCard = _SummaryCard(
        title: 'Cảnh báo',
        value: '$warningCount',
        icon: Icons.warning_amber_rounded,
        color: const Color.fromARGB(255, 220, 139, 17),
      );
      middleCard = _SummaryCard(
        title: 'Tổng nhật ký',
        value: '$warningCount',
        icon: Icons.list_alt_rounded,
        color: AppTheme.reportColor,
      );
      rightCard = _SummaryCard(
        title: 'Sự kiện khác',
        value: '0',
        icon: Icons.monitor_heart_rounded,
        color: AppTheme.activityColor,
      );
    } else {
      leftCard = _SummaryCard(
        title: 'Bất thường',
        value: '$abnormalCount',
        icon: Icons.emergency_rounded,
        color: Colors.red,
      );
      middleCard = _SummaryCard(
        title: 'Tổng nhật ký',
        value: '$total',
        icon: Icons.list_alt_rounded,
        color: AppTheme.reportColor,
      );
      rightCard = _SummaryCard(
        title: 'Bình thường',
        value: '${(total - abnormalCount).clamp(0, total)}',
        icon: Icons.monitor_heart_rounded,
        color: AppTheme.activityColor,
      );
    }

    return Row(
      children: [
        Expanded(child: leftCard),
        const SizedBox(width: 12),
        Expanded(child: middleCard),
        const SizedBox(width: 12),
        Expanded(child: rightCard),
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
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A202C),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                softWrap: true,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.unselectedTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onClearFilters;
  final VoidCallback? onRefresh;
  const _EmptyState({this.onClearFilters, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Color(0xFF6B7280),
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
            'Thử điều chỉnh tìm kiếm hoặc bộ lọc',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.unselectedTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onClearFilters != null)
                ElevatedButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Xóa bộ lọc'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                ),
              if (onClearFilters != null && onRefresh != null)
                const SizedBox(width: 8),
              if (onRefresh != null)
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Làm mới'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
