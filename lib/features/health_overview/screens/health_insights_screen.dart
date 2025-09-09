import 'package:detect_care_caregiver_app/features/health_overview/data/health_report_service.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';

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

  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

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
        title: Text('Insights • $rangeText'),
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
              ? const Center(child: Text('No data'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: _buildContent(context, _data!),
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
        : 'previous range';

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
        _CompareRangesFromApiCard(
          periodLabel: prevLabel,
          current: current,
          previous: previous,
          delta: delta,
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
                  'AI Recommendations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...d.aiRecommendations.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("• "),
                        Expanded(
                          child: Text(
                            r,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
    final color = count > 0 ? AppTheme.dangerColor : AppTheme.successColor;
    final label = count > 0
        ? 'Cần xử lý ngay'
        : 'Không có cảnh báo nguy hiểm treo';

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.priority_high_rounded, color: color),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pending “danger”: $count',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onViewLogs,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Xem log'),
          ),
        ],
      ),
    );
  }
}

class _CompareRangesFromApiCard extends StatelessWidget {
  final RangeStatsDto current;
  final RangeStatsDto previous;
  final RangeDeltaPctDto delta;
  final String periodLabel;

  const _CompareRangesFromApiCard({
    required this.current,
    required this.previous,
    required this.delta,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    String _pct(num v) => '${(v * 100).toStringAsFixed(0)}%';

    Widget item(
      String title,
      String value,
      String deltaStr, {
      Color? color,
      IconData? icon,
    }) {
      final isUp = deltaStr.startsWith('+') && deltaStr != '+0%';
      final ic =
          icon ??
          (isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded);
      final c = color ?? (isUp ? AppTheme.dangerColor : AppTheme.successColor);

      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withValues(alpha: .2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(ic, size: 16, color: c),
                  const SizedBox(width: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    deltaStr,
                    style: TextStyle(color: c, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
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
              Icon(Icons.compare_arrows_rounded, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Compare to last range',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'So với: $periodLabel',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              item('Total events', '${current.total}', delta.totalEventsPct),
              const SizedBox(width: 10),
              item(
                'Resolved %',
                _pct(current.resolvedTrueRate),
                delta.resolvedTrueRatePct,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              item(
                'False alarm %',
                _pct(current.falseAlertRate),
                delta.falseAlertRatePct,
              ),
              const SizedBox(width: 10),
              item('Danger (count)', '${current.danger}', delta.dangerPct),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Prev: total ${previous.total} • resolved ${_pct(previous.resolvedTrueRate)} • false ${_pct(previous.falseAlertRate)} • danger ${previous.danger}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
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
              'Top event type: $label',
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
