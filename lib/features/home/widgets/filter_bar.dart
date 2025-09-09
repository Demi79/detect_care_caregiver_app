import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class FilterBar extends StatelessWidget {
  final List<String> statusOptions;
  final List<String> periodOptions;

  final DateTimeRange? selectedDayRange;

  final String selectedStatus;
  final String selectedPeriod;

  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<DateTimeRange?> onDayRangeChanged;
  final ValueChanged<String?> onPeriodChanged;

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
  });

  DateTimeRange _todayRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: start, end: start);
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  onStatusChanged('All');
                  onDayRangeChanged(_todayRange());
                  onPeriodChanged('All');
                },
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Hàng 1: Day (căn giữa)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Expanded(child: _buildDayRangeChip(context))],
          ),
          const SizedBox(height: 12),

          // Hàng 2: Status + Period (căn giữa)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildDropdownChip(
                  context: context,
                  label: 'Status',
                  selectedValue: selectedStatus,
                  options: statusOptions,
                  onChanged: onStatusChanged,
                  icon: Icons.health_and_safety_rounded,
                  color: _getStatusColor(selectedStatus),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownChip(
                  context: context,
                  label: 'Period',
                  selectedValue: selectedPeriod,
                  options: periodOptions,
                  onChanged: onPeriodChanged,
                  icon: Icons.wb_sunny_rounded,
                  color: AppTheme.reportColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayRangeChip(BuildContext context) {
    final Color color = AppTheme.activityColor;
    final DateTimeRange displayRange = selectedDayRange ?? _todayRange();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              'Day',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          onTap: () async {
            final today = DateTime.now();

            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2023, 1, 1),
              lastDate: DateTime(today.year, today.month, today.day),
              initialDateRange: selectedDayRange ?? _todayRange(),
              helpText: 'Select Date Range',
              saveText: 'Apply',
              cancelText: 'Cancel',
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    dialogBackgroundColor: Colors.white,
                    scaffoldBackgroundColor: Colors.white,
                    colorScheme: ColorScheme.light(
                      primary: Colors.blue.shade300,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Colors.black87,
                      secondary: Colors.blue.shade300,
                      onSecondary: Colors.white,
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade300,
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) onDayRangeChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBackground,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedDayRange != null)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  '${_fmtDate(displayRange.start)} → ${_fmtDate(displayRange.end)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownChip({
    required BuildContext context,
    required String label,
    required String selectedValue,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBackground,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              onChanged: onChanged,
              isDense: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: color,
                size: 20,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.text,
                fontWeight: FontWeight.w500,
              ),
              items: options.map((String option) {
                final bool isSel = option == selectedValue;
                return DropdownMenuItem<String>(
                  value: option,
                  child: Row(
                    children: [
                      if (isSel)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        option,
                        style: TextStyle(
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                          color: isSel ? color : AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'danger':
      case 'critical':
        return AppTheme.dangerColor;
      case 'warning':
        return AppTheme.warningColor;
      case 'normal':
        return AppTheme.successColor;
      default:
        return AppTheme.primaryBlue;
    }
  }
}
