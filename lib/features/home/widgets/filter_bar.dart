import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../constants/filter_constants.dart';
import '../../../core/utils/backend_enums.dart' as be;

class FilterBar extends StatelessWidget {
  final List<String> statusOptions;
  final List<String> periodOptions;
  final DateTimeRange? selectedDayRange;
  final String selectedStatus;
  final String selectedPeriod;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<DateTimeRange?> onDayRangeChanged;
  final ValueChanged<String?> onPeriodChanged;
  final bool showStatus;
  final bool showPeriod;
  final bool enforceTwoDayRange;
  final int? maxRangeDays;
  final int? maxPastMonths;
  final int? maxPastDays;

  static const List<Map<String, String>> timeSlots = [
    {'label': '00:00-06:00', 'value': '00-06'},
    {'label': '06:00-12:00', 'value': '06-12'},
    {'label': '12:00-18:00', 'value': '12-18'},
    {'label': '18:00-24:00', 'value': '18-24'},
  ];

  const FilterBar({
    super.key,
    required this.statusOptions,
    required this.periodOptions,
    required this.selectedDayRange,
    required this.selectedStatus,
    required this.selectedPeriod,
    required this.onStatusChanged,
    required this.onDayRangeChanged,
    required this.onPeriodChanged,
    this.showStatus = true,
    this.showPeriod = true,
    this.enforceTwoDayRange = false,
    this.maxRangeDays,
    this.maxPastMonths,
    this.maxPastDays,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultRange = HomeFilters.defaultDayRange;

    final bool hasCustomStatus =
        _normalize(selectedStatus) != _normalize('abnormal');
    final bool hasCustomPeriod =
        _normalize(selectedPeriod) != _normalize('all');
    final bool hasCustomDayRange =
        selectedDayRange != null &&
        !_isSameRange(selectedDayRange, defaultRange);

    String summary = '';
    if (hasCustomDayRange && selectedDayRange != null) {
      final sameDay = _isSameDay(
        selectedDayRange!.start,
        selectedDayRange!.end,
      );
      final dayStr = _formatDateVN(selectedDayRange!.start);
      final endDayStr = _formatDateVN(selectedDayRange!.end);
      if (sameDay) {
        summary = dayStr;
      } else {
        summary = '$dayStr → $endDayStr';
      }
    }
    if (hasCustomPeriod && selectedPeriod != 'all') {
      final slot = timeSlots.firstWhere(
        (e) => e['value'] == selectedPeriod,
        orElse: () => {'label': selectedPeriod, 'value': selectedPeriod},
      );
      summary =
          '${slot['label']} ${summary.isNotEmpty ? summary : _formatDateVN(selectedDayRange?.start ?? DateTime.now())}';
    }
    if (hasCustomStatus) {
      summary =
          'Trạng thái = ${_translateStatus(selectedStatus)}${summary.isNotEmpty ? ' • $summary' : ''}';
    }
    if (summary.isNotEmpty) {
      summary = 'Đang áp dụng: $summary';
    }

    return Card(
      elevation: 1,
      color: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        side: BorderSide(
          color: Color.lerp(colorScheme.outlineVariant, Colors.white, 0.4)!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, defaultRange),
            // if (hasActiveFilters && summary.isNotEmpty) ...[
            //   const SizedBox(height: 12),
            //   _buildAppliedSummary(context, summary, defaultRange),
            // ],
            const SizedBox(height: 16),
            () {
              final List<Widget> pills = [];

              pills.add(
                _LabeledPill(
                  icon: Icons.schedule_rounded,
                  accentColor: AppTheme.successColor,
                  label: 'Ngày',
                  value: _formatRangeVN(
                    selectedDayRange ?? HomeFilters.defaultDayRange,
                  ),
                  highlight: hasCustomDayRange,
                  onTap: () => enforceTwoDayRange
                      ? _pickDateRangeReport(
                          context,
                          selectedDayRange ?? defaultRange,
                          defaultRange,
                        )
                      : _pickDateRange(
                          context,
                          selectedDayRange ?? defaultRange,
                          defaultRange,
                        ),
                ),
              );

              if (showStatus) {
                pills.add(const SizedBox(height: 16));
                pills.add(
                  _LabeledPill(
                    icon: Icons.place_outlined,
                    accentColor: AppTheme.primaryBlue,
                    label: 'Trạng thái',
                    value: _translateStatus(selectedStatus),
                    highlight: hasCustomStatus,
                    onTap: () => _selectStatus(context),
                  ),
                );
              }

              if (showPeriod) {
                pills.add(const SizedBox(height: 16));
                pills.add(
                  _LabeledPill(
                    icon: Icons.auto_awesome_rounded,
                    accentColor: _Palette.stageAccent,
                    label: 'Khung giờ',
                    value: _getTimeSlotLabel(selectedPeriod),
                    highlight: hasCustomPeriod,
                    onTap: () => _selectPeriod(context),
                  ),
                );
              }

              return Column(children: pills);
            }(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DateTimeRange defaultRange) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color.lerp(colorScheme.primary, Colors.white, 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.tune_rounded, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          'Bộ lọc',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => _reset(defaultRange),
          child: const Text('Đặt lại'),
        ),
      ],
    );
  }

  // Widget _buildAppliedSummary(
  //   BuildContext context,
  //   String summary,
  //   DateTimeRange defaultRange,
  // ) {
  //   final colorScheme = Theme.of(context).colorScheme;
  //   final textTheme = Theme.of(context).textTheme;
  //   final Color chipColor = Color.lerp(colorScheme.primary, Colors.white, 0.9)!;

  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //     decoration: BoxDecoration(
  //       color: chipColor,
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(Icons.filter_alt_outlined, size: 18, color: colorScheme.primary),
  //         const SizedBox(width: 8),
  //         Expanded(
  //           child: Text(
  //             'Đang áp dụng: $summary',
  //             style: textTheme.bodyMedium?.copyWith(
  //               fontWeight: FontWeight.w500,
  //               color: colorScheme.primary,
  //               height: 1.3,
  //             ),
  //           ),
  //         ),
  //         TextButton(
  //           onPressed: () => _reset(defaultRange),
  //           child: const Text('Bỏ hết'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _pickDateRange(
    BuildContext context,
    DateTimeRange initial,
    DateTimeRange fallback,
  ) async {
    final DateTime today = DateTime.now();

    DateTime computeFirstDate() {
      final base = DateTime(2023, 1, 1);
      // If a strict maxRangeDays is provided (e.g., 3), prefer to limit
      // the selectable window to the last `maxRangeDays` days relative to today.
      if (maxRangeDays != null) {
        final limitedByRange = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: maxRangeDays! - 1));
        return limitedByRange.isAfter(base) ? limitedByRange : base;
      }

      if (maxPastDays != null) {
        final limitedByDays = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: maxPastDays!));
        return limitedByDays.isAfter(base) ? limitedByDays : base;
      }
      if (maxPastMonths == null) return base;
      final limited = DateTime(
        today.year,
        today.month - maxPastMonths!,
        today.day,
      );
      return limited.isAfter(base) ? limited : base;
    }

    // Use the standard date range picker UI; restrict overall window by first/lastDate
    final DateTime firstDate = computeFirstDate();
    final DateTime lastDate = DateTime(today.year, today.month, today.day);

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initial,
      locale: const Locale('vi', 'VN'),
      selectableDayPredicate:
          (DateTime day, DateTime? rangeStart, DateTime? rangeEnd) {
            if (day.isBefore(firstDate) || day.isAfter(lastDate)) return false;

            if (maxRangeDays != null) {
              if (rangeStart != null && rangeEnd == null) {
                final span = (day.difference(rangeStart).inDays).abs() + 1;
                return span <= maxRangeDays!;
              }
              if (rangeStart == null && rangeEnd != null) {
                final span = (rangeEnd.difference(day).inDays).abs() + 1;
                return span <= maxRangeDays!;
              }
            }

            return true;
          },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.primaryBlue),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFFF8FAFC),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDayRangeChanged(
        DateTimeRange(
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day),
        ),
      );
    } else if (selectedDayRange == null) {
      onDayRangeChanged(fallback);
    }
  }

  Future<void> _pickDateRangeReport(
    BuildContext context,
    DateTimeRange initial,
    DateTimeRange fallback,
  ) async {
    final today = DateTime.now();

    DateTime computeFirstDate() {
      final base = DateTime(2023, 1, 1);
      if (maxPastDays != null) {
        final limitedByDays = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: maxPastDays!));
        return limitedByDays.isAfter(base) ? limitedByDays : base;
      }
      if (maxPastMonths == null) return base;
      final limited = DateTime(
        today.year,
        today.month - maxPastMonths!,
        today.day,
      );
      return limited.isAfter(base) ? limited : base;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.start,
      firstDate: computeFirstDate(),
      lastDate: DateTime(today.year, today.month, today.day),
      locale: const Locale('vi', 'VN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.primaryBlue),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFFF8FAFC),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final startDate = DateTime(picked.year, picked.month, picked.day);
      DateTime endDate = startDate.add(const Duration(days: 1));

      final todayDate = DateTime(today.year, today.month, today.day);

      if (endDate.isAfter(todayDate)) {
        endDate = todayDate;
        final yesterday = todayDate.subtract(const Duration(days: 1));
        onDayRangeChanged(DateTimeRange(start: yesterday, end: endDate));
        return;
      }

      onDayRangeChanged(DateTimeRange(start: startDate, end: endDate));
    } else if (selectedDayRange == null) {
      onDayRangeChanged(fallback);
    }
  }

  Future<void> _selectStatus(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        backgroundColor: const Color(0xFFF8FAFC),
        title: Center(child: const Text('Chọn trạng thái')),
        children: statusOptions
            .map(
              (status) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, status),
                child: Text(_translateStatus(status)),
              ),
            )
            .toList(),
      ),
    );
    if (result != null) {
      onStatusChanged(result);
    }
  }

  Future<void> _selectPeriod(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        backgroundColor: const Color(0xFFF8FAFC),
        title: Center(child: const Text('Chọn khung giờ')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'all'),
            child: const Text('Tất cả khung giờ'),
          ),
          ...timeSlots.map(
            (slot) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, slot['value']),
              child: Text(slot['label']!),
            ),
          ),
        ],
      ),
    );
    if (result != null) {
      onPeriodChanged(result);
    }
  }

  void _reset(DateTimeRange defaultRange) {
    onStatusChanged(HomeFilters.defaultStatus);
    onPeriodChanged(HomeFilters.defaultPeriod);
    onDayRangeChanged(defaultRange);
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isSameRange(DateTimeRange? a, DateTimeRange? b) {
    if (a == null || b == null) return false;
    return _isSameDay(a.start, b.start) && _isSameDay(a.end, b.end);
  }

  // Removed unused _formatRange and _formatDate

  static String _normalize(String value) => value.toLowerCase();

  String _translateStatus(String status) {
    final s = status.toLowerCase();
    if (s == 'all') return 'Tất cả trạng thái';
    if (s == 'abnormal') return 'Bất thường';
    return be.BackendEnums.statusToVietnamese(s);
  }

  String _getTimeSlotLabel(String slotValue) {
    if (slotValue.toLowerCase() == 'all') return 'Tất cả khung giờ';
    final slot = timeSlots.firstWhere(
      (e) => e['value'] == slotValue,
      orElse: () => {'label': slotValue, 'value': slotValue},
    );
    return slot['label']!;
  }

  String _formatDateVN(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';

  String _formatRangeVN(DateTimeRange range) {
    final sameDay = _isSameDay(range.start, range.end);
    final start = _formatDateVN(range.start);
    final end = _formatDateVN(range.end);
    return sameDay ? start : '$start → $end';
  }
}

class _LabeledPill extends StatelessWidget {
  const _LabeledPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.onTap,
    required this.highlight,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final VoidCallback onTap;
  final bool highlight;

  Color _towardsWhite(double amount) =>
      Color.lerp(accentColor, Colors.white, amount)!;

  Color _towardsBlack(double amount) =>
      Color.lerp(accentColor, Colors.black, amount)!;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final Color background = _towardsWhite(highlight ? 0.82 : 0.9);
    final Color borderColor = _towardsWhite(highlight ? 0.65 : 0.8);
    final Color labelColor = _towardsBlack(0.18);
    final Color valueColor = _towardsBlack(0.15);
    final Color affordanceColor = _towardsBlack(0.2);
    final Color indicatorColor = _towardsBlack(0.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: labelColor),
            const SizedBox(width: 6),
            Text(
              label,
              style:
                  textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ) ??
                  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: affordanceColor.withValues(alpha: 31),
            highlightColor: affordanceColor.withValues(alpha: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style:
                          textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: valueColor,
                            height: 1.25,
                          ) ??
                          TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: valueColor,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: affordanceColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Palette {
  static final Color stageAccent = Color.lerp(
    AppTheme.reportColor,
    const Color(0xFF8B5CF6),
    0.6,
  )!;
}
