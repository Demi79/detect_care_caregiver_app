import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/home/widgets/filter_bar.dart';
import 'package:flutter/material.dart';

import '../constants/filter_constants.dart';
import '../widgets/action_log_card.dart';

class CancelEventLogScreen extends StatefulWidget {
  final List<LogEntry> logs;
  final DateTimeRange? selectedDayRange;
  final String selectedStatus;
  final String selectedPeriod;

  final ValueChanged<DateTimeRange?> onDayRangeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPeriodChanged;
  final VoidCallback? onRefresh;
  final void Function(String eventId, {bool? confirmed})? onEventUpdated;

  const CancelEventLogScreen({
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
  State<CancelEventLogScreen> createState() => _CancelEventLogScreenState();
}

class _CancelEventLogScreenState extends State<CancelEventLogScreen> {
  DateTimeRange? _selectedDayRange;
  late String _selectedStatus;
  late String _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _selectedDayRange = widget.selectedDayRange;
    _selectedStatus = widget.selectedStatus;
    _selectedPeriod = widget.selectedPeriod;
  }

  @override
  Widget build(BuildContext context) {
    final logs = widget.logs;
    final filtered = logs.where((log) {
      final st = log.status.toLowerCase();
      final selectedSt = _selectedStatus.toLowerCase();

      bool statusMatches = true;
      if (selectedSt == 'abnormal') {
        statusMatches = st == 'danger' || st == 'warning';
      } else if (selectedSt != 'all') {
        statusMatches = st == selectedSt;
      }
      if (!statusMatches) return false;

      final rawDt = log.detectedAt ?? log.createdAt;
      if (rawDt == null) return false;
      final dt = rawDt.toLocal();

      if (_selectedDayRange != null) {
        final dateOnly = DateTime(dt.year, dt.month, dt.day);
        final start = DateTime(
          _selectedDayRange!.start.year,
          _selectedDayRange!.start.month,
          _selectedDayRange!.start.day,
        );
        final end = DateTime(
          _selectedDayRange!.end.year,
          _selectedDayRange!.end.month,
          _selectedDayRange!.end.day,
        );
        if (dateOnly.isBefore(start) || dateOnly.isAfter(end)) return false;
      }

      final slot = _selectedPeriod.toLowerCase();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF374151),
              size: 18,
            ),
          ),
        ),
        title: const Text(
          'Danh sách sự kiện đã hủy',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        // actions: [
        //   Container(
        //     margin: const EdgeInsets.all(8),
        //     decoration: BoxDecoration(
        //       color: const Color(0xFFF8FAFC),
        //       borderRadius: BorderRadius.circular(12),
        //       border: Border.all(color: const Color(0xFFE2E8F0)),
        //     ),
        //     child: IconButton(
        //       onPressed: _load,
        //       icon: const Icon(
        //         Icons.refresh,
        //         color: Color(0xFF64748B),
        //         size: 20,
        //       ),
        //     ),
        //   ),
        // ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FilterBar(
                statusOptions: const ['abnormal', 'danger', 'warning'],
                periodOptions: HomeFilters.periodOptions,
                selectedDayRange: _selectedDayRange,
                selectedStatus: _selectedStatus,
                selectedPeriod: _selectedPeriod,
                onDayRangeChanged: (dr) {
                  setState(() => _selectedDayRange = dr);
                  try {
                    widget.onDayRangeChanged(dr);
                  } catch (_) {}
                },
                onStatusChanged: (s) {
                  setState(
                    () => _selectedStatus = s ?? HomeFilters.defaultStatus,
                  );
                  try {
                    widget.onStatusChanged(s);
                  } catch (_) {}
                },
                onPeriodChanged: (p) {
                  setState(
                    () => _selectedPeriod = p ?? HomeFilters.defaultPeriod,
                  );
                  try {
                    widget.onPeriodChanged(p);
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 24),
              _SummaryRow(logs: filtered),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              if (filtered.isEmpty)
                _EmptyState(
                  onClearFilters: () {
                    setState(() {
                      _selectedDayRange = HomeFilters.defaultDayRange;
                      _selectedStatus = HomeFilters.defaultStatus;
                      _selectedPeriod = HomeFilters.defaultPeriod;
                    });
                    try {
                      widget.onDayRangeChanged(HomeFilters.defaultDayRange);
                      widget.onStatusChanged(HomeFilters.defaultStatus);
                      widget.onPeriodChanged(HomeFilters.defaultPeriod);
                    } catch (_) {}
                  },
                  onRefresh: widget.onRefresh,
                )
              else
                ...filtered.map((log) {
                  try {
                    print(
                      '[CancelEventLogScreen] event=${log.eventId} confirm=${log.confirmStatus} status=${log.status} detectedAt=${log.detectedAt}',
                    );
                  } catch (_) {}
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ActionLogCard(
                      data: log,
                      onUpdated: (newStatus, {bool? confirmed}) => widget
                          .onEventUpdated
                          ?.call(log.eventId, confirmed: confirmed),
                    ),
                  );
                }),
            ],
          ),
        ),
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
            title: 'Cảnh báo',
            value: '$critical',
            icon: Icons.emergency_rounded,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'Tổng nhật ký',
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
                color: color.withValues(alpha: 0.1),
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
