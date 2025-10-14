import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../constants/filter_constants.dart';

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultRange = HomeFilters.defaultDayRange;

    final bool hasCustomStatus =
        _normalize(selectedStatus) != _normalize(HomeFilters.defaultStatus);
    final bool hasCustomPeriod =
        _normalize(selectedPeriod) != _normalize(HomeFilters.defaultPeriod);
    final bool hasCustomDayRange =
        selectedDayRange != null &&
        !_isSameRange(selectedDayRange, defaultRange);
    final bool hasActiveFilters =
        hasCustomStatus || hasCustomPeriod || hasCustomDayRange;

    final appliedParts = <String>[];
    if (hasCustomDayRange && selectedDayRange != null) {
      appliedParts.add('Ngày = ${_formatRange(selectedDayRange!)}');
    }
    if (hasCustomStatus) {
      appliedParts.add('Trạng thái = ${_translateStatus(selectedStatus)}');
    }
    if (hasCustomPeriod) {
      appliedParts.add('Giai đoạn = ${_translatePeriod(selectedPeriod)}');
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
            if (hasActiveFilters) ...[
              const SizedBox(height: 12),
              _buildAppliedSummary(
                context,
                appliedParts.join(' • '),
                defaultRange,
              ),
            ],
            const SizedBox(height: 16),
            _LabeledPill(
              icon: Icons.schedule_rounded,
              accentColor: AppTheme.successColor,
              label: 'Ngày',
              value: _formatRange(
                selectedDayRange ?? HomeFilters.defaultDayRange,
              ),
              highlight: hasCustomDayRange,
              onTap: () => _pickDateRange(
                context,
                selectedDayRange ?? defaultRange,
                defaultRange,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _LabeledPill(
                    icon: Icons.place_outlined,
                    accentColor: AppTheme.primaryBlue,
                    label: 'Trạng thái',
                    value: _translateStatus(selectedStatus),
                    highlight: hasCustomStatus,
                    onTap: () => _selectStatus(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabeledPill(
                    icon: Icons.auto_awesome_rounded,
                    accentColor: _Palette.stageAccent,
                    label: 'Giai đoạn',
                    value: _translatePeriod(selectedPeriod),
                    highlight: hasCustomPeriod,
                    onTap: () => _selectPeriod(context),
                  ),
                ),
              ],
            ),
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

  Widget _buildAppliedSummary(
    BuildContext context,
    String summary,
    DateTimeRange defaultRange,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final Color chipColor = Color.lerp(colorScheme.primary, Colors.white, 0.9)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_outlined, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đang áp dụng: $summary',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.primary,
                height: 1.3,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _reset(defaultRange),
            child: const Text('Bỏ hết'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(
    BuildContext context,
    DateTimeRange initial,
    DateTimeRange fallback,
  ) async {
    final DateTime today = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: initial,
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

  Future<void> _selectStatus(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Chọn trạng thái'),
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
        title: const Text('Chọn giai đoạn'),
        children: periodOptions
            .map(
              (period) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, period),
                child: Text(_translatePeriod(period)),
              ),
            )
            .toList(),
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

  static String _formatRange(DateTimeRange range) =>
      '${_formatDate(range.start)} → ${_formatDate(range.end)}';

  static String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _normalize(String value) => value.toLowerCase();

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'all':
        return 'Tất cả trạng thái';
      case 'danger':
      case 'critical':
        return 'Nguy hiểm';
      case 'warning':
        return 'Cảnh báo';
      case 'normal':
        return 'Bình thường';
      default:
        return status;
    }
  }

  String _translatePeriod(String period) {
    switch (period.toLowerCase()) {
      case 'all':
        return 'Tất cả giai đoạn';
      case 'morning':
        return 'Buổi sáng';
      case 'afternoon':
        return 'Buổi chiều';
      case 'evening':
        return 'Buổi tối';
      case 'night':
        return 'Ban đêm';
      default:
        return period;
    }
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
