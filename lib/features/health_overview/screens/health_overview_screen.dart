import 'package:detect_care_caregiver_app/features/health_overview/data/health_report_service.dart';
import 'package:detect_care_caregiver_app/features/home/constants/filter_constants.dart';
import 'package:detect_care_caregiver_app/features/home/widgets/filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/health_overview/widgets/high_risk_time_table.dart';
import 'package:intl/intl.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../widgets/overview_widgets.dart';
import 'analyst_data_screen.dart';

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
  int _kpiTotalEvents = 0;
  int _kpiTotalAbnormal = 0;
  int _kpiTotalFall = 0;
  int _kpiTotalAbnormalBehavior = 0;
  HighRiskTimeDto? _computedHighRiskTime;
  List<dynamic> _filteredLogs = [];
  bool _analystLoading = false;
  String? _analystError;
  List<dynamic>? _analystEntries;

  @override
  void initState() {
    super.initState();
    _fetch();
    // In debug mode, automatically run the event comparison after the first
    // frame so developers don't need to press the debug button manually.
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
      // compute client-side resolved rate (average of ACKNOWLEDGED and RESOLVED rates)
      await _computeResolvedRate(r);
      await _fetchAnalystSummaries(r);
    } catch (e) {
      print('[HEALTH_OVERVIEW] fetch error: $e');
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _computeResolvedRate(DateTimeRange range) async {
    try {
      final svc = EventService.withDefaultClient();
      // fetch a large page so we capture most events in the selected range
      final logs = await svc.fetchLogs(
        dayRange: range,
        period: (_selectedPeriod == 'All' || _selectedPeriod.isEmpty)
            ? null
            : _selectedPeriod,
      );

      // Debug: print fetched logs summary to diagnose duplicate / unexpected rows
      try {
        print('[HEALTH_OVERVIEW] fetched logs count=${logs.length}');
        final ids = logs.map((l) => l.eventId).toList();
        print(
          '[HEALTH_OVERVIEW] fetched eventIds sample=${ids.take(20).toList()}',
        );

        // Per-item brief info
        for (var i = 0; i < logs.length; i++) {
          try {
            final l = logs[i];
            print(
              '[HEALTH_OVERVIEW] item[$i] id=${l.eventId} type=${l.eventType} status=${l.status} lifecycle=${l.lifecycleState} detected=${l.detectedAt} created=${l.createdAt}',
            );
          } catch (e) {
            print('[HEALTH_OVERVIEW] item[$i] - failed to print: $e');
          }
        }

        // Duplicate summary
        final dup = <String, int>{};
        for (final id in ids) {
          dup[id] = (dup[id] ?? 0) + 1;
        }
        final duplicates = dup.entries.where((e) => e.value > 1).toList();
        print(
          '[HEALTH_OVERVIEW] duplicate id counts=${duplicates.map((e) => '${e.key}:${e.value}').toList()}',
        );
      } catch (e) {
        print('[HEALTH_OVERVIEW] debug print failed: $e');
      }

      // Exclude events that have been canceled at the lifecycle level
      final filtered = logs
          .where(
            (l) =>
                (l.lifecycleState?.toString().toLowerCase() ?? '') !=
                'canceled',
          )
          .toList();

      if (filtered.isEmpty) {
        setState(() {
          _kpiTotalEvents = 0;
          _kpiTotalAbnormal = 0;
          _kpiTotalFall = 0;
          _kpiTotalAbnormalBehavior = 0;
          _computedHighRiskTime = HighRiskTimeDto(
            morning: 0,
            afternoon: 0,
            evening: 0,
            night: 0,
            topLabel: '',
          );
          _filteredLogs = filtered;
        });
        return;
      }

      final total = filtered.length;
      final int fallCount = filtered
          .where((l) => l.eventType.toLowerCase() == 'fall')
          .length;
      final int abnormalBehaviorCount = filtered
          .where((l) => l.eventType.toLowerCase() == 'abnormal_behavior')
          .length;
      final int abnormalCount = filtered.where((l) {
        final s = l.status.toLowerCase();
        return s == 'danger' || s == 'warning';
      }).length;

      // Compute high-risk time buckets from filtered logs
      int morning = 0, afternoon = 0, evening = 0, night = 0;
      for (final e in filtered) {
        final detected = e.detectedAt;
        if (detected == null) continue;
        final localH = detected.toLocal().hour;
        if (localH >= 5 && localH < 12) {
          morning++;
        } else if (localH >= 12 && localH < 18) {
          afternoon++;
        } else if (localH >= 18 && localH < 22) {
          evening++;
        } else {
          night++;
        }
      }

      String topKey = '';
      final map = {
        'morning': morning,
        'afternoon': afternoon,
        'evening': evening,
        'night': night,
      };
      if (map.values.any((v) => v > 0)) {
        topKey = map.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      }

      setState(() {
        _kpiTotalEvents = total;
        _kpiTotalAbnormal = abnormalCount;
        _kpiTotalFall = fallCount;
        _kpiTotalAbnormalBehavior = abnormalBehaviorCount;
        _computedHighRiskTime = HighRiskTimeDto(
          morning: morning,
          afternoon: afternoon,
          evening: evening,
          night: night,
          topLabel: topKey,
        );
        _filteredLogs = filtered;
      });
    } catch (e) {
      print('[HEALTH_OVERVIEW] computeResolvedRate failed: $e');
      // keep _computedResolvedRate null so UI falls back to server-provided value
    }
  }

  String _fmtDdMmY(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  Future<void> _fetchAnalystSummaries(DateTimeRange range) async {
    setState(() {
      _analystLoading = true;
      _analystError = null;
      _analystEntries = null;
    });

    try {
      final userId = widget.patientId ?? await AuthStorage.getUserId();
      if (userId == null) throw Exception('User id not available');
      final from = _fmtDdMmY(range.start);
      final to = _fmtDdMmY(range.end);

      final res = await _remote.fetchAnalystUserJsonRange(
        userId: userId,
        from: from,
        to: to,
        includeData: true,
      );

      if (res is Map && res['data'] is List) {
        setState(() => _analystEntries = List.from(res['data'] as List));
      } else {
        setState(() => _analystEntries = []);
      }
    } catch (e) {
      setState(() => _analystError = e.toString());
    } finally {
      setState(() => _analystLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      // appBar: AppBar(
      //   title: Text('Tổng quan sức khỏe • $rangeText'),
      //   backgroundColor: Colors.white,
      //   foregroundColor: AppTheme.text,
      //   elevation: 0.5,
      //   actions: [
      //     if (kDebugMode)
      //       IconButton(
      //         tooltip: 'Debug: compare events',
      //         icon: const Icon(Icons.bug_report),
      //         onPressed: _debugCompareEvents,
      //       ),
      //   ],
      // ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingXS,
              vertical: AppTheme.spacingL,
            ),
            children: [
              if (_loading) const LoadingWidget(),
              if (!_loading && _error != null)
                ErrorDisplay(error: _error!, onRetry: _fetch),
              if (!_loading && _error == null && _data == null)
                const Center(child: Text('Không có dữ liệu')),
              if (!_loading && _data != null) _buildContent(context, _data!),
            ],
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
  //   final svc = EventService.withDefaultClient();
  //   try {
  //     print(
  //       '[DEBUG] Requesting events for ${r.start}..${r.end} (period=Afternoon)',
  //     );
  //     final logsAf = await svc.fetchLogs(
  //       page: 1,
  //       limit: 1000,
  //       dayRange: DateTimeRange(start: r.start, end: r.end),
  //       period: 'Afternoon',
  //     );

  //     print(
  //       '[DEBUG] EventService returned ${logsAf.length} items (period=Afternoon)',
  //     );

  //     print(
  //       '[DEBUG] Requesting events for ${r.start}..${r.end} (no period)',
  //     );
  //     final logsAll = await svc.fetchLogs(
  //       page: 1,
  //       limit: 1000,
  //       dayRange: DateTimeRange(start: r.start, end: r.end),
  //     );
  //     print(
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

  //     print(
  //       '[DEBUG] Local group counts -> morning=$morning, afternoon=$afternoon, evening=$evening, night=$night',
  //     );
  //     print(
  //       '[DEBUG] UTC group counts   -> morning=$utcMorning, afternoon=$utcAfternoon, evening=$utcEvening, night=$utcNight',
  //     );
  //     print(
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
  //     print('[DEBUG] fetchLogs failed: $e');
  //     if (mounted) {
  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(SnackBar(content: Text('DEBUG: fetch failed: $e')));
  //     }
  //   }
  // }

  Widget _buildContent(BuildContext context, HealthReportOverviewDto d) {
    // KPIs (counts) are computed client-side in _computeResolvedRate and
    // stored in state variables: _kpiTotalEvents, _kpiTotalAbnormal,
    // _kpiTotalFall, _kpiTotalAbnormalBehavior.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterBar(
          statusOptions: HomeFilters.statusOptions,
          periodOptions: HomeFilters.periodOptions,
          selectedDayRange: _selectedDayRange,
          selectedStatus: _selectedStatus,
          selectedPeriod: _selectedPeriod,
          enforceTwoDayRange: true,
          onStatusChanged: (v) =>
              setState(() => _selectedStatus = v ?? HomeFilters.defaultStatus),
          onDayRangeChanged: (r) => setState(() {
            _selectedDayRange = r;
            _fetch();
          }),
          onPeriodChanged: (v) =>
              setState(() => _selectedPeriod = v ?? HomeFilters.defaultPeriod),
          showStatus: false,
          showPeriod: false,
        ),
        const SizedBox(height: AppTheme.spacingL),

        KPITiles(
          totalEvents: _kpiTotalEvents,
          totalAbnormal: _kpiTotalAbnormal,
          totalFall: _kpiTotalFall,
          totalAbnormalBehavior: _kpiTotalAbnormalBehavior,
        ),
        const SizedBox(height: AppTheme.spacingL),
        // Prefer client-computed high-risk time (which excludes canceled events)
        // fall back to server-provided values when computation is not available.
        (() {
          final highRisk = _computedHighRiskTime ?? d.highRiskTime;
          final highlight = (highRisk.topLabel.isNotEmpty)
              ? highRisk.topLabel
              : null;
          return HighRiskTimeTable(
            morning: highRisk.morning,
            afternoon: highRisk.afternoon,
            evening: highRisk.evening,
            night: highRisk.night,
            highlightKey: highlight,
          );
        }()),
        const SizedBox(height: AppTheme.spacingL),

        // Status breakdown: derive counts strictly from client-filtered logs
        (() {
          int danger = 0, warning = 0, normal = 0;
          for (final l in _filteredLogs) {
            try {
              final s = (l.status ?? '').toString().toLowerCase();
              if (s == 'danger') {
                danger++;
              } else if (s == 'warning')
                warning++;
              else
                normal++;
            } catch (_) {
              normal++;
            }
          }

          return StatusBreakdownBar(
            danger: danger,
            warning: warning,
            normal: normal,
          );
        }()),
        const SizedBox(height: AppTheme.spacingL),

        // Container(
        //   padding: const EdgeInsets.all(AppTheme.spacingM),
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //     borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        //     boxShadow: AppTheme.cardShadow,
        //   ),
        //   child: Text(
        //     d.aiSummary.isEmpty ? "Không có tóm tắt AI" : d.aiSummary,
        //     style: Theme.of(context).textTheme.bodyMedium,
        //   ),
        // ),
        // const SizedBox(height: AppTheme.spacingM),

        // --- KẾT LUẬN TỪNG NGÀY (daily conclusions) ---
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          margin: const EdgeInsets.only(top: AppTheme.spacingM),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Phân tích hoạt động',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // TextButton(
                  //   onPressed: () async {
                  //     // open date range picker and refresh both overview & analyst
                  //     final picked = await showDateRangePicker(
                  //       context: context,
                  //       firstDate: DateTime(2020),
                  //       lastDate: DateTime.now(),
                  //       initialDateRange: _selectedDayRange ?? _todayRange(),
                  //       builder: (context, child) => Theme(
                  //         data: Theme.of(context).copyWith(
                  //           colorScheme: ColorScheme.light(
                  //             primary: AppTheme.primaryBlue,
                  //           ),
                  //         ),
                  //         child: child!,
                  //       ),
                  //     );
                  //     if (picked != null) {
                  //       setState(() {
                  //         _selectedDayRange = picked;
                  //       });
                  //       await _fetch();
                  //     }
                  //   },
                  //   child: const Text('Chọn khoảng'),
                  // ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AnalystDataScreen(
                            dayRange: _selectedDayRange,
                            userId: widget.patientId,
                          ),
                        ),
                      );
                    },
                    child: const Text('Xem đầy đủ'),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              if (_analystLoading)
                const Center(child: CircularProgressIndicator())
              else if (_analystError != null)
                Text('Lỗi tải kết luận: $_analystError'),

              // else if (_analystEntries == null || _analystEntries!.isEmpty)
              //   const Text('Không có kết luận cho khoảng thời gian này')
              // else
              //   Column(
              //     crossAxisAlignment: CrossAxisAlignment.stretch,
              //     children: _analystEntries!.map((e) {
              //       final m = (e as Map<String, dynamic>);
              //       final data = m['data'];
              //       String summary = '';
              //       if (data != null && data['analyses'] is List) {
              //         try {
              //           final analyses = (data['analyses'] as List).firstWhere(
              //             (a) =>
              //                 a is Map<String, dynamic> &&
              //                 a['suggest_summary_daily'] != null,
              //             orElse: () => null,
              //           );
              //           if (analyses != null &&
              //               analyses is Map<String, dynamic>) {
              //             summary =
              //                 analyses['suggest_summary_daily']?.toString() ??
              //                 '';
              //           }
              //         } catch (_) {}
              //       }

              //       final date = m['date']?.toString() ?? '';
              //       return Container(
              //         margin: const EdgeInsets.only(top: AppTheme.spacingS),
              //         padding: const EdgeInsets.all(AppTheme.spacingS),
              //         decoration: BoxDecoration(
              //           color: AppTheme.primaryBlue.withAlpha(
              //             (0.03 * 255).round(),
              //           ),
              //           borderRadius: BorderRadius.circular(8),
              //         ),
              //         child: Row(
              //           children: [
              //             Expanded(
              //               child: Column(
              //                 crossAxisAlignment: CrossAxisAlignment.start,
              //                 children: [
              //                   Text(
              //                     date,
              //                     style: Theme.of(context).textTheme.bodySmall
              //                         ?.copyWith(color: AppTheme.textSecondary),
              //                   ),
              //                   const SizedBox(height: 6),
              //                   Text(
              //                     summary.isEmpty
              //                         ? 'Không có kết luận'
              //                         : summary,
              //                     style: Theme.of(context).textTheme.bodyMedium,
              //                   ),
              //                 ],
              //               ),
              //             ),
              //           ],
              //         ),
              //       );
              //     }).toList(),
              //   ),
            ],
          ),
        ),

        // const SizedBox(height: AppTheme.spacingXL),
        // Container(
        //   padding: const EdgeInsets.all(AppTheme.spacingM),
        //   margin: const EdgeInsets.only(top: AppTheme.spacingM),
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //     borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        //     boxShadow: AppTheme.cardShadow,
        //   ),
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.stretch,
        //     children: [
        //       Row(
        //         children: [
        //           Expanded(
        //             child: Text(
        //               'Gợi ý từ AI',
        //               style: Theme.of(context).textTheme.titleMedium?.copyWith(
        //                 fontWeight: FontWeight.w700,
        //               ),
        //             ),
        //           ),

        //           TextButton(
        //             onPressed: () {
        //               Navigator.of(context).push(
        //                 MaterialPageRoute(
        //                   builder: (_) => HealthInsightsScreen(
        //                     dayRange: _selectedDayRange,
        //                     patientId: widget.patientId,
        //                   ),
        //                 ),
        //               );
        //             },
        //             child: const Text('Xem chi tiết'),
        //           ),
        //         ],
        //       ),

        //       // const SizedBox(height: AppTheme.spacingS),
        //       // if (_analystLoading)
        //       //   const Center(child: CircularProgressIndicator())
        //       // else if (_analystError != null)
        //       //   Text('Lỗi tải kết luận: $_analystError')
        //       // else if (_analystEntries == null || _analystEntries!.isEmpty)
        //       //   const Text('Không có kết luận cho khoảng thời gian này')
        //       // else
        //       //   Column(
        //       //     crossAxisAlignment: CrossAxisAlignment.stretch,
        //       //     children: _analystEntries!.map((e) {
        //       //       final m = (e as Map<String, dynamic>);
        //       //       final data = m['data'];
        //       //       String summary = '';
        //       //       if (data != null && data['analyses'] is List) {
        //       //         try {
        //       //           final analyses = (data['analyses'] as List).firstWhere(
        //       //             (a) =>
        //       //                 a is Map<String, dynamic> &&
        //       //                 a['suggest_summary_daily'] != null,
        //       //             orElse: () => null,
        //       //           );
        //       //           if (analyses != null &&
        //       //               analyses is Map<String, dynamic>) {
        //       //             summary =
        //       //                 analyses['suggest_summary_daily']?.toString() ??
        //       //                 '';
        //       //           }
        //       //         } catch (_) {}
        //       //       }

        //       //       final date = m['date']?.toString() ?? '';
        //       //       return Container(
        //       //         margin: const EdgeInsets.only(top: AppTheme.spacingS),
        //       //         padding: const EdgeInsets.all(AppTheme.spacingS),
        //       //         decoration: BoxDecoration(
        //       //           color: AppTheme.primaryBlue.withOpacity(0.03),
        //       //           borderRadius: BorderRadius.circular(8),
        //       //         ),
        //       //         child: Row(
        //       //           children: [
        //       //             Expanded(
        //       //               child: Column(
        //       //                 crossAxisAlignment: CrossAxisAlignment.start,
        //       //                 children: [
        //       //                   Text(
        //       //                     date,
        //       //                     style: Theme.of(context).textTheme.bodySmall
        //       //                         ?.copyWith(color: AppTheme.textSecondary),
        //       //                   ),
        //       //                   const SizedBox(height: 6),
        //       //                   Text(
        //       //                     summary.isEmpty
        //       //                         ? 'Không có kết luận'
        //       //                         : summary,
        //       //                     style: Theme.of(context).textTheme.bodyMedium,
        //       //                   ),
        //       //                 ],
        //       //               ),
        //       //             ),
        //       //           ],
        //       //         ),
        //       //       );
        //       //     }).toList(),
        //       //   ),
        //     ],
        //   ),
        // ),

        // SectionHeader(
        //   title: 'Báo cáo chi tiết',
        //   onViewAll: () {
        //     Navigator.of(context).push(
        //       MaterialPageRoute(
        //         builder: (_) => HealthInsightsScreen(
        //           dayRange: _selectedDayRange,
        //           patientId: widget.patientId,
        //         ),
        //       ),
        //     );
        //   },
        // ),
        const SizedBox(height: AppTheme.spacingS),
      ],
    );
  }
}
