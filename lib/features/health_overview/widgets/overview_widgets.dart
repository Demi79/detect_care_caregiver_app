import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class KPITiles extends StatelessWidget {
  final int totalEvents;
  final int totalAbnormal; // danger + warning
  final int totalFall;
  final int totalAbnormalBehavior;

  const KPITiles({
    super.key,
    required this.totalEvents,
    required this.totalAbnormal,
    required this.totalFall,
    required this.totalAbnormalBehavior,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final twoCols = c.maxWidth < 520;

        final tiles = <Widget>[
          _KPICard(
            title: 'Tổng sự kiện',
            value: '$totalEvents',
            icon: Icons.notifications_active_rounded,
            color: AppTheme.primaryBlue,
          ),
          _KPICard(
            title: 'Tổng bất thường',
            value: '$totalAbnormal',
            icon: Icons.report_problem_rounded,
            color: Colors.orange,
          ),
          _KPICard(
            title: 'Số sự kiện ngã',
            value: '$totalFall',
            icon: Icons.personal_injury_rounded,
            color: const Color(0xFFE53E3E),
          ),
          _KPICard(
            title: 'Số hành vi bất thường',
            value: '$totalAbnormalBehavior',
            icon: Icons.monitor_heart_rounded,
            color: const Color(0xFFD53F8C),
          ),
        ];

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: twoCols ? 2 : 4,
            crossAxisSpacing: AppTheme.spacingM,
            mainAxisSpacing: AppTheme.spacingM,
            childAspectRatio: twoCols ? 1.6 : 2.2,
          ),
          itemBuilder: (_, i) => tiles[i],
        );
      },
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _KPICard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
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
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          () {
            final double leftIndent = 36.0 + AppTheme.spacingS;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: leftIndent),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.text,
                            fontSize: 24,
                            height: 1.0,
                          ),
                    ),
                  ),
                ),
              ),
            );
          }(),
        ],
      ),
    );
  }
}

class WeeklyAlertsBar extends StatelessWidget {
  final List<int> counts;
  final List<String> labels;
  const WeeklyAlertsBar({super.key, required this.counts, required this.labels})
    : assert(counts.length == labels.length);

  @override
  Widget build(BuildContext context) {
    final maxVal = (counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b))
        .clamp(1, 999);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
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
              Icon(
                Icons.bar_chart_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Sự kiện bất thường (7 ngày)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),

          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(counts.length, (i) {
                final h = (counts[i] <= 0) ? 4.0 : 100.0 * counts[i] / maxVal;
                return Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: h,
                      width: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: List.generate(labels.length, (i) {
              return Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 2),

          Row(
            children: List.generate(counts.length, (i) {
              return Expanded(
                child: Text(
                  '${counts[i]}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class StatusBreakdownBar extends StatelessWidget {
  final int danger;
  final int warning;
  final int normal;
  const StatusBreakdownBar({
    super.key,
    required this.danger,
    required this.warning,
    required this.normal,
  });

  @override
  Widget build(BuildContext context) {
    final total = (danger + warning + normal).clamp(1, 1 << 30);
    final d = danger / total;
    final w = warning / total;
    final n = normal / total;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
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
              Icon(
                Icons.segment_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Phân bố trạng thái',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Expanded(
                  flex: (d * 1000).round(),
                  child: Container(height: 14, color: Colors.red),
                ),
                Expanded(
                  flex: (w * 1000).round(),
                  child: Container(height: 14, color: Colors.orange),
                ),
                Expanded(
                  flex: (n * 1000).round(),
                  child: Container(height: 14, color: AppTheme.primaryBlue),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Wrap(
            spacing: 12,
            children: const [
              _LegendDot(color: Colors.red, label: 'Nguy hiểm'),
              _LegendDot(color: Colors.orange, label: 'Cảnh báo'),
              _LegendDot(color: Colors.blue, label: 'Bình thường'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class TimeOfDayHistogram extends StatelessWidget {
  final int morning; // 05:00–11:59
  final int afternoon; // 12:00–17:59
  final int evening; // 18:00–21:59
  final int night; // 22:00–04:59

  const TimeOfDayHistogram({
    super.key,
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.night,
  });

  @override
  Widget build(BuildContext context) {
    final arr = [morning, afternoon, evening, night];
    final maxVal = (arr.reduce((a, b) => a > b ? a : b)).clamp(1, 999);

    Widget bar(String label, int v) {
      final h = (v <= 0) ? 6.0 : 100.0 * v / maxVal;
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: h,
              width: 16,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              // localize time-of-day labels
              label,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
            Text(
              '$v',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
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
              Icon(
                Icons.schedule_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Khung giờ trong ngày (khoảng đã chọn)',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                bar('Buổi sáng', morning),
                bar('Buổi trưa', afternoon),
                bar('Buổi chiều', evening),
                bar('Buổi tối', night),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResolutionGauge extends StatelessWidget {
  final int confirmedTrue;
  final int confirmedFalse;
  // final int pending;
  const ResolutionGauge({
    super.key,
    required this.confirmedTrue,
    required this.confirmedFalse,
    // required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final total = (confirmedTrue + confirmedFalse).clamp(1, 1 << 30);
    final rate = confirmedTrue / total;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            height: 82,
            width: 82,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey.withValues(alpha: .15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.grey.withValues(alpha: .15),
                  ),
                ),
                CircularProgressIndicator(
                  value: rate,
                  strokeWidth: 10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                Text(
                  '${(rate * 100).toStringAsFixed(0)}%',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.donut_large_rounded,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tỷ lệ đã xử lý (khoảng đã chọn)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                _row('Xác nhận (đúng)', confirmedTrue, Colors.blue),
                _row('Báo động giả', confirmedFalse, Colors.orange),
                // _row('Pending', pending, Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, int val, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(label)),
          Text('$val', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
