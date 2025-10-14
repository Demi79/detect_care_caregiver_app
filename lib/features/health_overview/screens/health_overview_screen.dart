import 'package:detect_care_caregiver_app/features/health_overview/data/health_report_service.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/features/health_overview/widgets/section_header.dart';
import 'package:detect_care_caregiver_app/features/home/constants/filter_constants.dart';
import 'package:detect_care_caregiver_app/features/home/widgets/filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/health_overview/widgets/high_risk_time_table.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // if (kDebugMode) {
      //   Future.delayed(const Duration(milliseconds: 400), () {
      //     _debugCompareEvents();
      //   });
      // }
    });
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
        ? 'Hôm nay'
        : '${_fmtDate(_selectedDayRange!.start)} → ${_fmtDate(_selectedDayRange!.end)}';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: Text('Tổng quan sức khỏe • $rangeText'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.text,
        elevation: 0.5,
        // actions: [
        //   if (kDebugMode)
        //     IconButton(
        //       tooltip: 'Debug: compare events',
        //       icon: const Icon(Icons.bug_report),
        //       onPressed: _debugCompareEvents,
        //     ),
        // ],
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: _buildContent(context, _data!),
                ),
        ),
      ),
    );
  }

  // Debug helper: fetch events from EventService for the currently selected
  // day range and 'Afternoon' period to compare counts with server-side
  // health report aggregation. Visible only in debug builds.
  // Future<void> _debugCompareEvents() async {
  //   if (!kDebugMode) {
  //     return;
  //   }
  //   final r = _selectedDayRange ?? _todayRange();
  //   // final svc = EventService(EventService.withDefaultClient());
  //   try {
  //     debugPrint(
  //       '[DEBUG] Requesting events for ${r.start}..${r.end} (period=Afternoon)',
  //     );
  //     final logsAf = await svc.fetchLogs(
  //       page: 1,
  //       limit: 1000,
  //       dayRange: DateTimeRange(start: r.start, end: r.end),
  //       period: 'Afternoon',
  //     );

  //     debugPrint(
  //       '[DEBUG] EventService returned ${logsAf.length} items (period=Afternoon)',
  //     );

  //     debugPrint(
  //       '[DEBUG] Requesting events for ${r.start}..${r.end} (no period)',
  //     );
  //     final logsAll = await svc.fetchLogs(
  //       page: 1,
  //       limit: 1000,
  //       dayRange: DateTimeRange(start: r.start, end: r.end),
  //     );
  //     debugPrint(
  //       '[DEBUG] EventService returned ${logsAll.length} items (no period)',
  //     );

  //     // Group logsAll by period using EventService._matchesPeriod logic equivalently
  //     int morning = 0, afternoon = 0, evening = 0, night = 0;
  //     // Also compute UTC-based grouping to compare with server behavior
  //     int utcMorning = 0, utcAfternoon = 0, utcEvening = 0, utcNight = 0;
  //     List<String> sampleAf = [];

  //     // Verbose sample collection (first 20)
  //     final samples = <String>[];
  //     var sampleCount = 0;

  //     for (final e in logsAll) {
  //       final detected = e.detectedAt;
  //       if (detected == null) {
  //         continue;
  //       }

  //       // local grouping
  //       final localH = detected.toLocal().hour;
  //       if (localH >= 5 && localH < 12) {
  //         morning++;
  //       } else if (localH >= 12 && localH < 18) {
  //         afternoon++;
  //         if (sampleAf.length < 5) {
  //           sampleAf.add(detected.toLocal().toIso8601String());
  //         }
  //       } else if (localH >= 18 && localH < 22) {
  //         evening++;
  //       } else {
  //         night++;
  //       }

  //       // UTC grouping
  //       final utcH = detected.toUtc().hour;
  //       if (utcH >= 5 && utcH < 12) {
  //         utcMorning++;
  //       } else if (utcH >= 12 && utcH < 18) {
  //         utcAfternoon++;
  //       } else if (utcH >= 18 && utcH < 22) {
  //         utcEvening++;
  //       } else {
  //         utcNight++;
  //       }

  //       if (sampleCount < 20) {
  //         sampleCount++;
  //         // collect id,type,status,detectedAt local+UTC,description,confidence
  //         final id = e.eventId;
  //         final type = e.eventType;
  //         final status = e.status;
  //         final desc = e.eventDescription ?? '';
  //         final conf = e.confidenceScore.toStringAsFixed(2);
  //         final localIso = detected.toLocal().toIso8601String();
  //         final utcIso = detected.toUtc().toIso8601String();
  //         final shortDesc = desc.length > 50
  //             ? '${desc.substring(0, 50)}...'
  //             : desc;
  //         samples.add(
  //           '[id:$id type:$type status:$status local:$localIso utc:$utcIso conf:$conf desc:$shortDesc]',
  //         );
  //       }
  //     }

  //     debugPrint(
  //       '[DEBUG] Local group counts -> morning=$morning, afternoon=$afternoon, evening=$evening, night=$night',
  //     );
  //     debugPrint(
  //       '[DEBUG] UTC group counts   -> morning=$utcMorning, afternoon=$utcAfternoon, evening=$utcEvening, night=$utcNight',
  //     );
  //     debugPrint(
  //       '[DEBUG] Sample events (${samples.length}) = ${samples.join(' | ')}',
  //     );

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             'DEBUG: local_af=$afternoon utc_af=$utcAfternoon total=${logsAll.length} samples=${samples.length}',
  //           ),
  //           duration: const Duration(seconds: 6),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint('[DEBUG] fetchLogs failed: $e');
  //     if (mounted) {
  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(SnackBar(content: Text('DEBUG: fetch failed: $e')));
  //     }
  //   }
  // }

  Widget _buildContent(BuildContext context, HealthReportOverviewDto d) {
    final abnormalRange = d.kpis.abnormalTotal;
    final resolvedRate = d.kpis.resolvedTrueRate;
    final avgResp = Duration(seconds: d.kpis.avgResponseSeconds);
    final overSlaCritical = d.kpis.openCriticalOverSla;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

        KPITiles(
          abnormalToday: abnormalRange,
          resolvedRate: resolvedRate,
          avgResponse: avgResp,
          openAlerts: overSlaCritical,
        ),
        const SizedBox(height: AppTheme.spacingL),

        HighRiskTimeTable(
          morning: d.highRiskTime.morning,
          afternoon: d.highRiskTime.afternoon,
          evening: d.highRiskTime.evening,
          night: d.highRiskTime.night,
          highlightKey: d.highRiskTime.topLabel,
        ),
        const SizedBox(height: AppTheme.spacingL),

        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Text(
            d.aiSummary.isEmpty ? "Không có tóm tắt AI" : d.aiSummary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXL),

        SectionHeader(
          title: 'AI & Thông tin hoạt động',
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
