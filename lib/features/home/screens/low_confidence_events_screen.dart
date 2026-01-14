import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/home/widgets/filter_bar.dart';
import 'package:flutter/material.dart';

import '../constants/filter_constants.dart';
import '../widgets/action_log_card.dart';

class LowConfidenceEventsScreen extends StatelessWidget {
  final List<LogEntry> logs;
  final List<LogEntry> allLogs;
  final DateTimeRange? selectedDayRange;
  final String selectedStatus;
  final String selectedPeriod;
  final ScrollController? scrollController;
  final Key? filterBarKey;

  final ValueChanged<DateTimeRange?> onDayRangeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPeriodChanged;
  final VoidCallback? onRefresh;
  final void Function(String eventId, {bool? confirmed})? onEventUpdated;

  const LowConfidenceEventsScreen({
    super.key,
    required this.logs,
    required this.allLogs,
    required this.selectedDayRange,
    required this.selectedStatus,
    required this.selectedPeriod,
    required this.onDayRangeChanged,
    required this.onStatusChanged,
    required this.onPeriodChanged,
    this.onRefresh,
    this.onEventUpdated,
    this.scrollController,
    this.filterBarKey,
  });

  @override
  Widget build(BuildContext context) {
    final lowAllowed = const {'unknowns', 'suspect'};
    final int totalAll = allLogs.length;

    final filtered = logs.where((log) {
      try {
        final ls = log.lifecycleState?.toString().toLowerCase();
        if (ls != null && ls == 'canceled') return false;
      } catch (_) {}
      final st = log.status.toLowerCase();
      if (!lowAllowed.contains(st)) return false;

      final selectedSt = selectedStatus.toLowerCase();

      bool statusMatches;
      if (selectedSt == 'all') {
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
        bool inSlot;
        switch (slot) {
          case '00-06':
            inSlot = hour >= 0 && hour < 6;
            break;
          case '06-12':
            inSlot = hour >= 6 && hour < 12;
            break;
          case '12-18':
            inSlot = hour >= 12 && hour < 18;
            break;
          case '18-24':
            inSlot = hour >= 18 && hour < 24;
            break;
          case 'morning':
            inSlot = hour >= 5 && hour < 12;
            break;
          case 'afternoon':
            inSlot = hour >= 12 && hour < 18;
            break;
          case 'evening':
            inSlot = hour >= 18 && hour < 22;
            break;
          case 'night':
            inSlot = hour >= 22 || hour < 5;
            break;
          default:
            inSlot = true;
        }
        if (!inSlot) return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      controller: scrollController,
      physics: filtered.isEmpty
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FilterBar(
            key: filterBarKey,
            statusOptions: const ['all', 'suspect', 'unknowns'],
            periodOptions: HomeFilters.periodOptions,
            selectedDayRange: selectedDayRange,
            selectedStatus: selectedStatus,
            selectedPeriod: selectedPeriod,
            maxRangeDays: 3,
            onDayRangeChanged: onDayRangeChanged,
            onStatusChanged: onStatusChanged,
            onPeriodChanged: onPeriodChanged,
          ),
          const SizedBox(height: 24),
          _SummaryRow(
            filteredLogs: filtered,
            allLogs: allLogs,
            selectedStatus: selectedStatus,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            _EmptyState(
              onClearFilters: () {
                onDayRangeChanged(HomeFilters.defaultDayRange);
                onStatusChanged('all');
                onPeriodChanged(HomeFilters.defaultPeriod);
              },
            )
          else
            ...filtered.map((log) {
              try {
                print(
                  '[LowConfidenceEventsScreen] event=${log.eventId} confirm=${log.confirmStatus} status=${log.status} detectedAt=${log.detectedAt}',
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
  const _SummaryRow({
    required this.filteredLogs,
    required this.allLogs,
    required this.selectedStatus,
  });
  final List<LogEntry> filteredLogs;
  final List<LogEntry> allLogs;
  final String selectedStatus;

  @override
  Widget build(BuildContext context) {
    final sel = selectedStatus.toLowerCase();

    final int suspectCount = filteredLogs.where((e) {
      try {
        return e.status.toLowerCase() == 'suspect';
      } catch (_) {
        return false;
      }
    }).length;

    final int unknownCount = filteredLogs.where((e) {
      try {
        return e.status.toLowerCase() == 'unknowns';
      } catch (_) {
        return false;
      }
    }).length;

    final int totalLow = suspectCount + unknownCount;
    final int totalAll = allLogs.length; // include canceled events for total

    late final Widget leftCard;
    late final Widget middleCard;
    late final Widget rightCard;

    middleCard = _SummaryCard(
      title: 'Tổng nhật ký',
      value: '$totalAll',
      icon: Icons.list_alt_rounded,
      color: AppTheme.reportColor,
    );

    if (sel == 'all') {
      leftCard = _SummaryCard(
        title: 'Đáng ngờ',
        value: '$suspectCount',
        icon: Icons.help_outline_rounded,
        color: const Color(0xFFF59E0B),
      );
      rightCard = _SummaryCard(
        title: 'Sự kiện khác',
        value: '$unknownCount',
        icon: Icons.help_outline_rounded,
        color: AppTheme.activityColor,
      );
    } else if (sel == 'suspect') {
      leftCard = _SummaryCard(
        title: 'Đáng ngờ',
        value: '$suspectCount',
        icon: Icons.help_outline_rounded,
        color: const Color(0xFFF59E0B),
      );
      rightCard = _SummaryCard(
        title: 'Sự kiện khác',
        value: '0',
        icon: Icons.help_outline_rounded,
        color: AppTheme.activityColor,
      );
    } else if (sel == 'unknowns') {
      leftCard = _SummaryCard(
        title: 'Không xác định',
        value: '$unknownCount',
        icon: Icons.help_outline_rounded,
        color: Colors.grey,
      );
      rightCard = _SummaryCard(
        title: 'Sự kiện khác',
        value: '0',
        icon: Icons.report_off_rounded,
        color: AppTheme.activityColor,
      );
    } else {
      leftCard = _SummaryCard(
        title: 'Đáng ngờ',
        value: '$suspectCount',
        icon: Icons.help_outline_rounded,
        color: const Color(0xFFF59E0B),
      );
      rightCard = _SummaryCard(
        title: 'Sự kiện khác',
        value: '$unknownCount',
        icon: Icons.help_outline_rounded,
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
          // const SizedBox(height: 8),
          // Text(
          //   'Thử điều chỉnh tìm kiếm hoặc bộ lọc',
          //   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          //     color: AppTheme.unselectedTextColor,
          //   ),
          //   textAlign: TextAlign.center,
          // ),
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
