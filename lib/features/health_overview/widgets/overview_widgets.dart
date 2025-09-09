import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class KPITiles extends StatelessWidget {
  final int abnormalToday;
  final double resolvedRate;
  final Duration avgResponse;
  final int openAlerts;

  const KPITiles({
    super.key,
    required this.abnormalToday,
    required this.resolvedRate,
    required this.avgResponse,
    required this.openAlerts,
  });

  String _fmtDur(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}g ${d.inMinutes % 60}p';
    return '${d.inMinutes}p';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final twoCols = c.maxWidth < 520;
        final textScale = MediaQuery.textScaleFactorOf(context);
        // Cao “mềm” theo layout + kẹp khi người dùng tăng cỡ chữ
        final tileHeight =
            ((twoCols ? 128.0 : 120.0) * textScale.clamp(1.0, 1.25)).clamp(
              118.0,
              168.0,
            );

        final tiles = <Widget>[
          _KPICard(
            title: 'Bất thường',
            value: '$abnormalToday',
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
          ),
          _KPICard(
            title: 'Tỷ lệ xử lý',
            value: '${(resolvedRate * 100).toStringAsFixed(0)}%',
            icon: Icons.task_alt_rounded,
            color: AppTheme.successColor,
          ),
          _KPICard(
            title: 'Ph.hồi TB',
            value: _fmtDur(avgResponse),
            icon: Icons.timer_rounded,
            color: AppTheme.primaryBlue,
          ),
          _KPICard(
            title: 'CB mở',
            value: '$openAlerts',
            icon: Icons.notifications_active_rounded,
            color: AppTheme.dangerColor,
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
            // dùng chiều cao cố định linh hoạt để tránh tràn đáy
            mainAxisExtent: tileHeight, // ← chìa khóa
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
    final textScale = MediaQuery.textScaleFactorOf(context);
    final pad = (AppTheme.spacingL * (textScale > 1.1 ? .85 : 1.0)).clamp(
      10.0,
      16.0,
    );

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // chống tràn đáy
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Giá trị lớn có FittedBox để tự thu nhỏ nếu thiếu chỗ
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyAlertsBar extends StatelessWidget {
  final List<int> counts;
  final List<String> labels; // ví dụ: ['T2','T3',...]
  const WeeklyAlertsBar({super.key, required this.counts, required this.labels})
    : assert(counts.length == labels.length);

  @override
  Widget build(BuildContext context) {
    final maxVal = (counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b))
        .clamp(1, 999);

    final screenH = MediaQuery.sizeOf(context).height;
    final chartH = (screenH * 0.18).clamp(120.0, 180.0);

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
              Expanded(
                child: Text(
                  'Bất thường (7 ngày)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),

          SizedBox(
            height: chartH,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${counts[i]}',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
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
    final d = danger / total, w = warning / total, n = normal / total;

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
              Expanded(
                child: Text(
                  'Trạng thái (7 ngày)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
              _LegendDot(color: Colors.red, label: 'Nguy'),
              _LegendDot(color: Colors.orange, label: 'Cảnh'),
              _LegendDot(color: Colors.blue, label: 'Thường'),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$v',
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final screenH = MediaQuery.sizeOf(context).height;
    final h = (screenH * 0.22).clamp(132.0, 200.0);

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
              Expanded(
                child: Text(
                  'Theo thời điểm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          SizedBox(
            height: h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                bar('Sáng', morning),
                bar('Chiều', afternoon),
                bar('Tối', evening),
                bar('Đêm', night),
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
  const ResolutionGauge({
    super.key,
    required this.confirmedTrue,
    required this.confirmedFalse,
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${(rate * 100).toStringAsFixed(0)}%',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                    Expanded(
                      child: Text(
                        'KQ xử lý',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                _row('Đúng', confirmedTrue, Colors.blue),
                _row('Giả', confirmedFalse, Colors.orange),
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
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$val',
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
