import 'package:detect_care_caregiver_app/features/health_overview/data/health_report_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';

class HealthInsightsScreen extends StatefulWidget {
  final String? patientId;
  final DateTimeRange? dayRange;

  const HealthInsightsScreen({super.key, this.patientId, this.dayRange});

  @override
  State<HealthInsightsScreen> createState() => _HealthInsightsScreenState();
}

class _HealthInsightsScreenState extends State<HealthInsightsScreen> {
  final _remote = HealthReportRemoteDataSource();

  bool _loading = false;
  String? _error;
  HealthReportInsightDto? _data;

  DateTimeRange get _curRange {
    final r = widget.dayRange;
    if (r != null) {
      final s = DateTime(r.start.year, r.start.month, r.start.day);
      final e = DateTime(r.end.year, r.end.month, r.end.day);
      return DateTimeRange(start: s, end: e);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: today, end: today);
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  String _fmtDate(DateTime dt) => DateFormat('dd/MM/yyyy').format(dt);

  final _numFmt = NumberFormat.decimalPattern();

  String _fmtCount(int v) => _numFmt.format(v);

  String _fmtPct(double v, {int fracDigits = 1}) =>
      '${v.toStringAsFixed(fracDigits)}%';

  String _safeDeltaString(String rawPct) {
    if (rawPct.isEmpty) return '—';
    try {
      final d = double.tryParse(rawPct);
      if (d != null) {
        final pct = d * 100.0;
        final sign = pct >= 0 ? '+' : '';
        return '$sign${pct.toStringAsFixed(1)}%';
      }
      if (rawPct.contains('%')) {
        final cleaned = rawPct.replaceAll('%', '').replaceAll('+', '').trim();
        final d2 = double.tryParse(cleaned);
        if (d2 != null) {
          final sign = rawPct.contains('+') || d2 >= 0 ? '+' : '';
          return '$sign${d2.toStringAsFixed(1)}%';
        }
      }
    } catch (_) {}
    return '—';
  }

  Future<void> _fetch() async {
    final r = _curRange;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dto = await _remote.insight(startDay: r.start, endDay: r.end);
      setState(() => _data = dto);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rt = _curRange;
    final rangeText = '${_fmtDate(rt.start)} → ${_fmtDate(rt.end)}';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Báo cáo sức khỏe'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.text,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: _loading
              ? const LoadingWidget()
              : (_error != null)
              ? ErrorDisplay(error: _error!, onRetry: _fetch)
              : (_data == null)
              ? const Center(child: Text('Không có dữ liệu'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                  initialDateRange: rt,
                                );
                                if (picked != null) {
                                  if (!mounted) return;

                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => HealthInsightsScreen(
                                        patientId: widget.patientId,
                                        dayRange: picked,
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(rangeText),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingM),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(72, 36),
                                      backgroundColor:
                                          AppTheme.primaryBlueLight,
                                      foregroundColor: AppTheme.primaryBlue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      final today = DateTime.now();
                                      final r = DateTimeRange(
                                        start: DateTime(
                                          today.year,
                                          today.month,
                                          today.day,
                                        ),
                                        end: DateTime(
                                          today.year,
                                          today.month,
                                          today.day,
                                        ),
                                      );
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => HealthInsightsScreen(
                                            patientId: widget.patientId,
                                            dayRange: r,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Hôm nay'),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(72, 36),
                                      backgroundColor:
                                          AppTheme.primaryBlueLight,
                                      foregroundColor: AppTheme.primaryBlue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      final now = DateTime.now();
                                      final r = DateTimeRange(
                                        start: DateTime(
                                          now.year,
                                          now.month,
                                          now.day,
                                        ).subtract(const Duration(days: 6)),
                                        end: DateTime(
                                          now.year,
                                          now.month,
                                          now.day,
                                        ),
                                      );
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => HealthInsightsScreen(
                                            patientId: widget.patientId,
                                            dayRange: r,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('7 ngày'),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(72, 36),
                                      backgroundColor:
                                          AppTheme.primaryBlueLight,
                                      foregroundColor: AppTheme.primaryBlue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      final now = DateTime.now();
                                      final r = DateTimeRange(
                                        start: DateTime(
                                          now.year,
                                          now.month,
                                          now.day,
                                        ).subtract(const Duration(days: 29)),
                                        end: DateTime(
                                          now.year,
                                          now.month,
                                          now.day,
                                        ),
                                      );
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => HealthInsightsScreen(
                                            patientId: widget.patientId,
                                            dayRange: r,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('30 ngày'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildContent(context, _data!),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, HealthReportInsightDto d) {
    final current = d.compareToLastRange.current;
    final previous = d.compareToLastRange.previous;
    final delta = d.compareToLastRange.delta;

    final prevStart = d.range.previous.startTimeUtc;
    final prevEnd = d.range.previous.endTimeUtc;
    final prevLabel = (prevStart != null && prevEnd != null)
        ? '${_fmtDate(prevStart.toLocal())} → ${_fmtDate(prevEnd.toLocal())}'
        : 'kỳ trước';

    Widget metricTile(
      String label,
      String value,
      String deltaRaw, {
      required Color upColor,
      required Color downColor,
      required bool invertForPercent,
    }) {
      final safe = _safeDeltaString(deltaRaw);
      final isUp = safe.startsWith('+');
      final c = (label == 'Đã xử lý (%)')
          ? (isUp ? AppTheme.successColor : AppTheme.dangerColor)
          : (isUp ? AppTheme.dangerColor : AppTheme.successColor);

      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: .14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Row(
              children: [
                Icon(
                  isUp
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 20,
                  color: c,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        safe,
                        style: TextStyle(color: c, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1) Pending Critical
        _PendingCriticalCard(
          count: d.pendingCritical.dangerPendingCount,
          onViewLogs: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đi tới màn log cảnh báo…')),
            );
          },
        ),
        const SizedBox(height: AppTheme.spacingL),

        // 2) Compare to last range
        Container(
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
                    Icons.compare_arrows_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'So sánh với kỳ trước',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Kỳ trước: $prevLabel',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  Expanded(
                    child: metricTile(
                      'Tổng',
                      _fmtCount(current.total),
                      delta.totalEventsPct,
                      upColor: AppTheme.dangerColor,
                      downColor: AppTheme.successColor,
                      invertForPercent: false,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: metricTile(
                      'Đã xử lý (%)',
                      _fmtPct(current.resolvedTrueRate * 100, fracDigits: 1),
                      delta.resolvedTrueRatePct,
                      upColor: AppTheme.successColor,
                      downColor: AppTheme.dangerColor,
                      invertForPercent: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  Expanded(
                    child: metricTile(
                      'Giả (%)',
                      _fmtPct(current.falseAlertRate * 100, fracDigits: 1),
                      delta.falseAlertRatePct,
                      upColor: AppTheme.dangerColor,
                      downColor: AppTheme.successColor,
                      invertForPercent: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: metricTile(
                      'Nguy cơ (số)',
                      _fmtCount(current.danger),
                      delta.dangerPct,
                      upColor: AppTheme.dangerColor,
                      downColor: AppTheme.successColor,
                      invertForPercent: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Kỳ trước: tổng ${previous.total} • đã xử lý ${(previous.resolvedTrueRate * 100).toStringAsFixed(1)}% • giả ${(previous.falseAlertRate * 100).toStringAsFixed(1)}% • nguy cơ ${previous.danger}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingL),

        // 3) Top Event Type
        if (d.topEventType.count > 0)
          _TopEventTypeCard(
            label: d.topEventType.type,
            count: d.topEventType.count,
          ),
        if (d.topEventType.count > 0)
          const SizedBox(height: AppTheme.spacingXL),

        // 4) AI Summary
        if (d.aiSummary.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Text(
              d.aiSummary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (d.aiSummary.isNotEmpty) const SizedBox(height: AppTheme.spacingL),

        // 5) AI Recommendations
        if (d.aiRecommendations.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gợi ý từ AI',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...d.aiRecommendations.map((r) {
                  String cta = 'Xem';
                  if (r.toLowerCase().contains('nhắc') ||
                      r.toLowerCase().contains('thuốc')) {
                    cta = 'Tạo nhắc';
                  } else if (r.toLowerCase().contains('kiểm tra') ||
                      r.toLowerCase().contains('check')) {
                    cta = 'Danh sách kiểm tra';
                  } else if (r.toLowerCase().contains('ngưỡng') ||
                      r.toLowerCase().contains('threshold')) {
                    cta = 'Đi tới cài đặt';
                  }

                  final priorityColor = AppTheme.warningColor;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingS,
                            vertical: AppTheme.spacingXS,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 26),
                            borderRadius: BorderRadius.circular(
                              AppTheme.borderRadiusSmall,
                            ),
                          ),
                          child: Text(
                            'Trung bình',
                            style: TextStyle(
                              color: priorityColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: Text(
                            r,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$cta — $r')),
                            );
                          },
                          child: Text(cta),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}

/* ================== Cards ================== */

class _PendingCriticalCard extends StatelessWidget {
  final int count;
  final VoidCallback onViewLogs;
  const _PendingCriticalCard({required this.count, required this.onViewLogs});

  @override
  Widget build(BuildContext context) {
    final isOk = count == 0;
    final color = isOk ? AppTheme.successColor : AppTheme.dangerColor;
    final title = isOk ? 'Không có cảnh báo nghiêm trọng' : 'Cần xử lý ngay';
    final subtitle = isOk
        ? 'Mọi thứ hiện đang ổn.'
        : 'Có $count cảnh báo nghiêm trọng đang chờ xử lý.';

    return InkWell(
      onTap: onViewLogs,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isOk ? Icons.check_circle_rounded : Icons.priority_high_rounded,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onViewLogs,
              icon: const Icon(Icons.history_rounded, size: 16),
              label: const Text('Xem log'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopEventTypeCard extends StatelessWidget {
  final String label;
  final int count;
  const _TopEventTypeCard({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.local_activity_rounded, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sự kiện phổ biến nhất: $label',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text('$count'),
        ],
      ),
    );
  }
}
