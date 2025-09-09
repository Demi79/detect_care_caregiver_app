import 'package:detect_care_caregiver_app/features/health_overview/data/health_report_service.dart';
import 'package:detect_care_caregiver_app/features/health_overview/widgets/section_header.dart';
import 'package:detect_care_caregiver_app/features/home/constants/filter_constants.dart';
import 'package:detect_care_caregiver_app/features/home/widgets/filter_bar.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';

import '../widgets/overview_widgets.dart';
import 'health_insights_screen.dart';

class HealthOverviewScreen extends StatefulWidget {
  final String? patientId;
  const HealthOverviewScreen({super.key, this.patientId});

  @override
  State<HealthOverviewScreen> createState() => _HealthOverviewScreenState();
}

class _HealthOverviewScreenState extends State<HealthOverviewScreen> {
  final _remote = HealthReportRemoteDataSource();

  DateTimeRange? _selectedDayRange = _todayRange();
  String _selectedStatus = HomeFilters.defaultStatus;
  String _selectedPeriod = HomeFilters.defaultPeriod;

  bool _loading = false;
  String? _error;
  HealthReportOverviewDto? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  static DateTimeRange _todayRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: start, end: start);
  }

  Future<void> _fetch() async {
    final r = _selectedDayRange ?? _todayRange();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dto = await _remote.overview(startDay: r.start, endDay: r.end);
      setState(() {
        _data = dto;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final rangeText = (_selectedDayRange == null)
        ? 'Today'
        : '${_fmtDate(_selectedDayRange!.start)} → ${_fmtDate(_selectedDayRange!.end)}';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: Text('Health Overview • $rangeText'),
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: _buildContent(context, _data!),
                ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, HealthReportOverviewDto d) {
    final abnormalRange = d.kpis.abnormalTotal;
    final resolvedRate = d.kpis.resolvedTrueRate;
    final avgResp = Duration(seconds: d.kpis.avgResponseSeconds);
    final overSlaCritical = d.kpis.openCriticalOverSla;

    String cap(String s) =>
        s.isEmpty ? '' : (s[0].toUpperCase() + s.substring(1).toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --------- FILTER BAR ----------
        FilterBar(
          statusOptions: HomeFilters.statusOptions,
          periodOptions: HomeFilters.periodOptions,
          selectedDayRange: _selectedDayRange,
          selectedStatus: _selectedStatus,
          selectedPeriod: _selectedPeriod,
          onStatusChanged: (v) =>
              setState(() => _selectedStatus = v ?? HomeFilters.defaultStatus),
          onDayRangeChanged: (r) => setState(() {
            _selectedDayRange = r;
            _fetch();
          }),
          onPeriodChanged: (v) =>
              setState(() => _selectedPeriod = v ?? HomeFilters.defaultPeriod),
        ),
        const SizedBox(height: AppTheme.spacingL),

        // --------- DASHBOARD ----------
        KPITiles(
          abnormalToday: abnormalRange,
          resolvedRate: resolvedRate,
          avgResponse: avgResp,
          openAlerts: overSlaCritical,
        ),
        const SizedBox(height: AppTheme.spacingL),

        // --------- HIGH RISK TIME ----------
        _HighRiskTimeCompact(
          morning: d.highRiskTime.morning,
          afternoon: d.highRiskTime.afternoon,
          evening: d.highRiskTime.evening,
          night: d.highRiskTime.night,
          highlightLabel: cap(d.highRiskTime.topLabel),
        ),
        const SizedBox(height: AppTheme.spacingL),

        // --------- AI SUMMARY ----------
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Text(
            d.aiSummary.isEmpty ? "No AI summary available" : d.aiSummary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXL),

        // --------- SECTION HEADER: AI & Activity Insights ----------
        SectionHeader(
          title: 'AI & Activity Insights',
          onViewAll: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HealthInsightsScreen(
                  dayRange: _selectedDayRange,
                  patientId: widget.patientId,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppTheme.spacingS),
      ],
    );
  }
}

/* ================== High-Risk Time compact (dashboard) ================== */
class _HighRiskTimeCompact extends StatelessWidget {
  final int morning, afternoon, evening, night;
  final String highlightLabel;

  const _HighRiskTimeCompact({
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.night,
    required this.highlightLabel,
  });

  @override
  Widget build(BuildContext context) {
    final map = {
      'Morning': morning,
      'Afternoon': afternoon,
      'Evening': evening,
      'Night': night,
    };
    final maxVal =
        (map.values.isEmpty ? 1 : map.values.reduce((a, b) => a > b ? a : b))
            .clamp(1, 999);

    Widget bar(String label, int v) {
      final h = (v <= 0) ? 6.0 : 100.0 * v / maxVal;
      final isHot = label == highlightLabel;
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: h,
              width: 16,
              decoration: BoxDecoration(
                color: isHot ? AppTheme.dangerColor : AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
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
                Icons.local_fire_department_rounded,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'High-Risk Time',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                bar('Morning', morning),
                bar('Afternoon', afternoon),
                bar('Evening', evening),
                bar('Night', night),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Khung giờ rủi ro cao: $highlightLabel',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
