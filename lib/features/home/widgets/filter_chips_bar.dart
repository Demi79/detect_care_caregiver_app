import 'package:flutter/material.dart';

class FilterChipsBar extends StatelessWidget {
  final String selectedStatus;
  final String selectedTimeRange;
  final String selectedPeriod;
  final List<String> statusOptions;
  final List<String> timeRangeOptions;
  final List<String> periodOptions;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onTimeRangeChanged;
  final ValueChanged<String?> onPeriodChanged;

  const FilterChipsBar({
    super.key,
    required this.selectedStatus,
    required this.selectedTimeRange,
    required this.selectedPeriod,
    required this.statusOptions,
    required this.timeRangeOptions,
    required this.periodOptions,
    required this.onStatusChanged,
    required this.onTimeRangeChanged,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ...statusOptions.map(
            (status) => ChoiceChip(
              label: Text(status),
              selected: selectedStatus == status,
              onSelected: (_) => onStatusChanged(status),
            ),
          ),
          ...timeRangeOptions.map(
            (time) => ChoiceChip(
              label: Text(time),
              selected: selectedTimeRange == time,
              onSelected: (_) => onTimeRangeChanged(time),
            ),
          ),
          ...periodOptions.map(
            (period) => ChoiceChip(
              label: Text(period),
              selected: selectedPeriod == period,
              onSelected: (_) => onPeriodChanged(period),
            ),
          ),
        ],
      ),
    );
  }
}
