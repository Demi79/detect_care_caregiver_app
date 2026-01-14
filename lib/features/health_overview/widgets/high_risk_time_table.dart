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
    'morning': 'Sáng',
    'afternoon': 'Chiều',
    'evening': 'Tối',
    'night': 'Đêm',
  };

  @override
  Widget build(BuildContext context) {
    final entries = [
      _RiskTimeEntry(
        key: 'morning',
        label: _labels['morning']!,
        count: morning,
      ),
      _RiskTimeEntry(
        key: 'afternoon',
        label: _labels['afternoon']!,
        count: afternoon,
      ),
      _RiskTimeEntry(
        key: 'evening',
        label: _labels['evening']!,
        count: evening,
      ),
      _RiskTimeEntry(key: 'night', label: _labels['night']!, count: night),
    ];

    final total = entries.fold<int>(0, (sum, e) => sum + e.count);
    final hasData = total > 0;

    _RiskTimeEntry? highlight;
    if (hasData) {
      if (highlightKey != null) {
        highlight = entries.firstWhere(
          (e) => e.key == highlightKey && e.count > 0,
          orElse: () => entries.first,
        );
      }
      highlight ??= entries.reduce((a, b) => a.count >= b.count ? a : b);
    }

    String pct(int c) {
      if (!hasData || c == 0) return '0%';
      final p = (c / total) * 100;
      return p >= 10 ? '${p.toStringAsFixed(0)}%' : '${p.toStringAsFixed(1)}%';
    }

    final textTheme = Theme.of(context).textTheme;
    final borderColor = AppTheme.borderColor.withAlpha(90);
    final headerBg = AppTheme.borderColor.withAlpha(30);
    final hlBg = AppTheme.dangerColor.withAlpha(30);
    final hlStroke = AppTheme.dangerColor.withAlpha(60);

    Widget headerCell(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style:
              textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ) ??
              const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );

    Widget dataCell(String text, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );

    Widget labelCell(_RiskTimeEntry e, bool hl) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // 🔹 center horizontally
        crossAxisAlignment: CrossAxisAlignment.center, // 🔹 center vertically
        children: [
          if (hl)
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
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              e.label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: hl ? FontWeight.w600 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
          /// Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withAlpha(30),
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
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (hasData)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha(20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Tổng: $total',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),

          /// Table
          Table(
            border: TableBorder.all(color: borderColor, width: 0.6),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(),
              1: FixedColumnWidth(88),
              2: FixedColumnWidth(88),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: headerBg),
                children: [
                  headerCell('Khung giờ'),
                  headerCell('Số lượng'),
                  headerCell('Tỷ lệ'),
                ],
              ),
              for (final e in entries)
                TableRow(
                  decoration: BoxDecoration(
                    color: highlight?.key == e.key ? hlBg : Colors.white,
                    border: highlight?.key == e.key
                        ? Border.all(color: hlStroke, width: 0.8)
                        : null,
                  ),
                  children: [
                    labelCell(e, highlight?.key == e.key),
                    dataCell('${e.count}', bold: highlight?.key == e.key),
                    dataCell(pct(e.count), bold: highlight?.key == e.key),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),

          /// Summary
          Text(
            hasData
                ? 'Khung giờ rủi ro cao: ${highlight?.label ?? '-'} (${pct(highlight?.count ?? 0)})'
                : 'Khung giờ rủi ro cao: Không có dữ liệu',
            style: textTheme.bodyMedium,
          ),
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
