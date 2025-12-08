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
      return DateTimeRange(
        start: DateTime(r.start.year, r.start.month, r.start.day),
        end: DateTime(r.end.year, r.end.month, r.end.day),
      );
    }
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day),
    );
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
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF374151),
              size: 18,
            ),
          ),
        ),
        title: const Text(
          'Báo cáo chi tiết',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
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
                      _DateRangeFilterCard(
                        currentRange: rt,
                        rangeText: rangeText,
                        onRangeSelected: (picked) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HealthInsightsScreen(
                                patientId: widget.patientId,
                                dayRange: picked,
                              ),
                            ),
                          );
                        },
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

    Widget metricTile(String label, String value, String deltaRaw) {
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
          border: Border.all(color: c.withAlpha((0.14 * 255).round())),
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
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  isUp ? Icons.trending_up : Icons.trending_down,
                  color: c,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                safe,
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PendingCriticalCard(
          count: d.pendingCritical.dangerPendingCount,
          onViewLogs: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đi tới màn log cảnh báo…')),
            );
          },
        ),
        const SizedBox(height: AppTheme.spacingL),
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
                  const Icon(
                    Icons.compare_arrows_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'So sánh với kỳ trước',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
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
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: metricTile(
                      'Đã xử lý (%)',
                      _fmtPct(current.resolvedTrueRate * 100),
                      delta.resolvedTrueRatePct,
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
                      _fmtPct(current.falseAlertRate * 100),
                      delta.falseAlertRatePct,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: metricTile(
                      'Nguy cơ (số)',
                      _fmtCount(current.danger),
                      delta.dangerPct,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kỳ trước: tổng ${previous.total}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    'Đã xử lý ${(previous.resolvedTrueRate * 100).toStringAsFixed(1)}% • Giả ${(previous.falseAlertRate * 100).toStringAsFixed(1)}% • Nguy cơ ${previous.danger}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingL),
        if (d.topEventType.count > 0)
          _TopEventTypeCard(
            label: d.topEventType.type,
            count: d.topEventType.count,
          ),
        if (d.aiSummary.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            margin: const EdgeInsets.only(top: AppTheme.spacingL),
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
        if (d.aiRecommendations.isNotEmpty)
          _AiRecommendationCard(recommendations: d.aiRecommendations),
      ],
    );
  }
}

// ----------------------- REDESIGNED DATE FILTER -----------------------

class _DateRangeFilterCard extends StatelessWidget {
  final DateTimeRange currentRange;
  final String rangeText;
  final Function(DateTimeRange) onRangeSelected;

  const _DateRangeFilterCard({
    required this.currentRange,
    required this.rangeText,
    required this.onRangeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withAlpha((0.05 * 255).round()),
            AppTheme.primaryBlueLight.withAlpha((0.1 * 255).round()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withAlpha((0.1 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.date_range_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Khoảng thời gian',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rangeText,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: currentRange,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppTheme.primaryBlue,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      onRangeSelected(picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: const Icon(
                      Icons.edit_calendar_rounded,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _QuickFilterChip(
                label: 'Hôm nay',
                icon: Icons.today_rounded,
                onTap: () {
                  final now = DateTime.now();
                  onRangeSelected(DateTimeRange(start: now, end: now));
                },
              ),
              const SizedBox(width: 8),
              _QuickFilterChip(
                label: '7 ngày',
                icon: Icons.date_range,
                onTap: () {
                  final now = DateTime.now();
                  onRangeSelected(
                    DateTimeRange(
                      start: now.subtract(const Duration(days: 6)),
                      end: now,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _QuickFilterChip(
                label: '30 ngày',
                icon: Icons.calendar_month_rounded,
                onTap: () {
                  final now = DateTime.now();
                  onRangeSelected(
                    DateTimeRange(
                      start: now.subtract(const Duration(days: 29)),
                      end: now,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: AppTheme.primaryBlue),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------- ORIGINAL CARDS -----------------------

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
                color: color.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isOk ? Icons.check_circle_rounded : Icons.priority_high_rounded,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
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
          const Icon(Icons.local_activity_rounded, color: AppTheme.primaryBlue),
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

// ----------------------- REDESIGNED AI RECOMMENDATION -----------------------

class _AiRecommendationCard extends StatelessWidget {
  final List<String> recommendations;
  const _AiRecommendationCard({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: AppTheme.primaryBlue.withAlpha((0.08 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: AppTheme.primaryBlue.withAlpha(
                  //       (0.3 * 255).round(),
                  //     ),
                  //     blurRadius: 8,
                  //     offset: const Offset(0, 2),
                  //   ),
                  // ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gợi ý từ AI',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${recommendations.length} khuyến nghị',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...recommendations.asMap().entries.map((entry) {
            final index = entry.key;
            final r = entry.value;

            String cta = 'Xem';
            IconData ctaIcon = Icons.arrow_forward_rounded;

            if (r.toLowerCase().contains('nhắc')) {
              cta = 'Tạo nhắc';
              ctaIcon = Icons.notifications_active_rounded;
            } else if (r.toLowerCase().contains('kiểm tra')) {
              cta = 'Kiểm tra';
              ctaIcon = Icons.checklist_rounded;
            } else if (r.toLowerCase().contains('ngưỡng')) {
              cta = 'Cài đặt';
              ctaIcon = Icons.settings_rounded;
            }

            return Container(
              margin: EdgeInsets.only(
                bottom: index < recommendations.length - 1 ? 12 : 0,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.warningColor.withAlpha((0.15 * 255).round()),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.02 * 255).round()),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withAlpha(
                            (0.15 * 255).round(),
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withAlpha(
                                  (0.12 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Độ ưu tiên: Trung bình',
                                style: TextStyle(
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              r,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(height: 1.5, color: AppTheme.text),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: AppTheme.primaryBlue.withAlpha(
                        (0.1 * 255).round(),
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$cta — $r')));
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cta,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryBlue,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                ctaIcon,
                                color: AppTheme.primaryBlue,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
