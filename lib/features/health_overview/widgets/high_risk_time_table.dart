import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class HighRiskTimeTable extends StatelessWidget {
  final int morning, afternoon, evening, night;
  final String? highlightKey;

  const HighRiskTimeTable({
    super.key,
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.night,
    this.highlightKey,
  });

  static const Map<String, String> _labels = {
    'morning': 'Buổi sáng',
    'afternoon': 'Buổi chiều',
    'evening': 'Buổi tối',
    'night': 'Ban đêm',
  };

  @override
  Widget build(BuildContext context) {
    final entries = [
      _RiskTimeEntry(
        key: 'morning',
        label: _labels['morning'] ?? 'Buổi sáng',
        count: morning,
      ),
      _RiskTimeEntry(
        key: 'afternoon',
        label: _labels['afternoon'] ?? 'Buổi chiều',
        count: afternoon,
      ),
      _RiskTimeEntry(
        key: 'evening',
        label: _labels['evening'] ?? 'Buổi tối',
        count: evening,
      ),
      _RiskTimeEntry(
        key: 'night',
        label: _labels['night'] ?? 'Ban đêm',
        count: night,
      ),
    ];

    _RiskTimeEntry? findByKey(String key) {
      for (final item in entries) {
        if (item.key == key) {
          return item;
        }
      }
      return null;
    }

    final total = entries.fold<int>(0, (sum, item) => sum + item.count);
    final hasData = total > 0;

    _RiskTimeEntry? highlight;
    if (hasData) {
      if (highlightKey != null) {
        final selected = findByKey(highlightKey!);
        if (selected != null && selected.count > 0) {
          highlight = selected;
        }
      }

      highlight ??= () {
        final topCount = entries.fold<int>(
          0,
          (value, entry) => entry.count > value ? entry.count : value,
        );
        if (topCount == 0) {
          return null;
        }
        final candidates = entries
            .where((entry) => entry.count == topCount)
            .toList();
        return candidates.length == 1 ? candidates.first : null;
      }();
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final borderColor = AppTheme.borderColor.withAlpha((0.35 * 255).round());
    final headerBackground = AppTheme.borderColor.withAlpha(
      (0.12 * 255).round(),
    );
    final highlightBackground = AppTheme.dangerColor.withAlpha(
      (0.12 * 255).round(),
    );
    final highlightStroke = AppTheme.dangerColor.withAlpha(
      (0.24 * 255).round(),
    );

    String percentageLabel(int count) {
      if (!hasData || count == 0) {
        return '0%';
      }
      final pct = (count / total) * 100.0;
      if (pct >= 99.5) {
        return '100%';
      }
      return pct >= 10
          ? '${pct.toStringAsFixed(0)}%'
          : '${pct.toStringAsFixed(1)}%';
    }

    String summaryText() {
      if (!hasData) {
        return 'Khung giờ rủi ro cao: Không có dữ liệu';
      }
      if (highlight == null) {
        return 'Khung giờ rủi ro cao: -';
      }
      return 'Khung giờ rủi ro cao: ${highlight.label} (${percentageLabel(highlight.count)})';
    }

    Widget headerCell(String title, {TextAlign align = TextAlign.left}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Text(
          title,
          textAlign: align,
          style:
              textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ) ??
              const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    Widget dataCell(
      String value, {
      TextAlign align = TextAlign.left,
      bool bold = false,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Text(
          value,
          textAlign: align,
          style:
              (align == TextAlign.right
                      ? textTheme.bodySmall
                      : textTheme.bodyMedium)
                  ?.copyWith(
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                  ) ??
              TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.w500),
        ),
      );
    }

    Widget labelCell(_RiskTimeEntry entry, bool isHighlight) {
      final baseStyle =
          textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
          ) ??
          TextStyle(
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
          );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            if (isHighlight)
              Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: AppTheme.dangerColor,
              )
            else
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.label,
                style: baseStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    final tableBorder = TableBorder(
      top: BorderSide(color: borderColor, width: 0.7),
      bottom: BorderSide(color: borderColor, width: 0.7),
      left: BorderSide(color: borderColor, width: 0.7),
      right: BorderSide(color: borderColor, width: 0.7),
      horizontalInside: BorderSide(color: borderColor, width: 0.6),
      verticalInside: BorderSide(color: borderColor, width: 0.6),
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withAlpha((0.12 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Khung Giờ Rủi Ro Cao',
                style:
                    textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ) ??
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (hasData)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha((0.08 * 255).round()),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Tổng: $total',
                    style:
                        textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ) ??
                        const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(),
              1: FixedColumnWidth(88),
              2: FixedColumnWidth(88),
            },
            border: tableBorder,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: headerBackground),
                children: [
                  headerCell('Khung giờ'),
                  headerCell('Số lượng', align: TextAlign.right),
                  headerCell('Tỷ lệ', align: TextAlign.right),
                ],
              ),
              for (final entry in entries)
                TableRow(
                  decoration: BoxDecoration(
                    color: highlight?.key == entry.key
                        ? highlightBackground
                        : Colors.white,
                    border: highlight?.key == entry.key
                        ? Border.all(color: highlightStroke, width: 0.9)
                        : null,
                  ),
                  children: [
                    labelCell(entry, highlight?.key == entry.key),
                    dataCell(
                      '${entry.count}',
                      align: TextAlign.right,
                      bold: highlight?.key == entry.key,
                    ),
                    dataCell(
                      percentageLabel(entry.count),
                      align: TextAlign.right,
                      bold: highlight?.key == entry.key,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(summaryText(), style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _RiskTimeEntry {
  final String key;
  final String label;
  final int count;

  const _RiskTimeEntry({
    required this.key,
    required this.label,
    required this.count,
  });
}
