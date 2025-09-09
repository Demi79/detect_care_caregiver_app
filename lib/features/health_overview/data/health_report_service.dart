import 'dart:convert';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '0') ?? 0;
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '0') ?? 0.0;
}

class HealthReportOverviewDto {
  final RangeDto range;
  final KpisDto kpis;
  final HighRiskTimeDto highRiskTime;
  final String aiSummary;

  // optional (nếu server có thể trả về trong tương lai)
  final StatusBreakdownDto? statusBreakdown;
  final List<TrendItemDto>? weeklyTrend;

  HealthReportOverviewDto({
    required this.range,
    required this.kpis,
    required this.highRiskTime,
    required this.aiSummary,
    this.statusBreakdown,
    this.weeklyTrend,
  });

  factory HealthReportOverviewDto.fromJson(Map<String, dynamic> json) {
    return HealthReportOverviewDto(
      range: RangeDto.fromJson(json['range'] ?? const {}),
      kpis: KpisDto.fromJson(json['kpis'] ?? const {}),
      highRiskTime: HighRiskTimeDto.fromJson(
        json['high_risk_time'] ?? const {},
      ),
      aiSummary: (json['ai_summary'] ?? '').toString(),
      statusBreakdown: json['status_breakdown'] != null
          ? StatusBreakdownDto.fromJson(json['status_breakdown'])
          : null,
      weeklyTrend: (json['weekly_trend'] as List?)
          ?.map((e) => TrendItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RangeDto {
  final DateTime? startTimeUtc;
  final DateTime? endTimeUtc;

  RangeDto({required this.startTimeUtc, required this.endTimeUtc});

  factory RangeDto.fromJson(Map<String, dynamic> j) => RangeDto(
    startTimeUtc: j['start_time'] != null
        ? DateTime.tryParse(j['start_time'].toString())
        : null,
    endTimeUtc: j['end_time'] != null
        ? DateTime.tryParse(j['end_time'].toString())
        : null,
  );
}

class KpisDto {
  final int abnormalTotal;
  final double resolvedTrueRate;
  final int avgResponseSeconds;
  final int openCriticalOverSla;

  KpisDto({
    required this.abnormalTotal,
    required this.resolvedTrueRate,
    required this.avgResponseSeconds,
    required this.openCriticalOverSla,
  });

  factory KpisDto.fromJson(Map<String, dynamic> j) => KpisDto(
    abnormalTotal: _asInt(j['abnormal_total']),
    resolvedTrueRate: _asDouble(j['resolved_true_rate']),
    avgResponseSeconds: _asInt(j['avg_response_seconds']),
    openCriticalOverSla: _asInt(j['open_critical_over_sla']),
  );
}

class StatusBreakdownDto {
  final int danger;
  final int warning;
  final int normal;

  StatusBreakdownDto({
    required this.danger,
    required this.warning,
    required this.normal,
  });

  factory StatusBreakdownDto.fromJson(Map<String, dynamic> j) =>
      StatusBreakdownDto(
        danger: _asInt(j['danger']),
        warning: _asInt(j['warning']),
        normal: _asInt(j['normal']),
      );
}

class TrendItemDto {
  final String date;
  final int count;
  final int resolvedTrue;

  TrendItemDto({
    required this.date,
    required this.count,
    required this.resolvedTrue,
  });

  factory TrendItemDto.fromJson(Map<String, dynamic> j) => TrendItemDto(
    date: (j['date'] ?? '').toString(),
    count: _asInt(j['count']),
    resolvedTrue: _asInt(j['resolved_true']),
  );
}

class HighRiskTimeDto {
  final int morning;
  final int afternoon;
  final int evening;
  final int night;
  final String topLabel;

  HighRiskTimeDto({
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.night,
    required this.topLabel,
  });

  factory HighRiskTimeDto.fromJson(Map<String, dynamic> j) => HighRiskTimeDto(
    morning: _asInt(j['morning']),
    afternoon: _asInt(j['afternoon']),
    evening: _asInt(j['evening']),
    night: _asInt(j['night']),
    topLabel: (j['top_label'] ?? '').toString(),
  );
}

class HealthReportInsightDto {
  final RangePairDto range;
  final PendingCriticalDto pendingCritical;
  final CompareToLastRangeDto compareToLastRange;
  final TopEventTypeDto topEventType;
  final String aiSummary;
  final List<String> aiRecommendations;

  HealthReportInsightDto({
    required this.range,
    required this.pendingCritical,
    required this.compareToLastRange,
    required this.topEventType,
    required this.aiSummary,
    required this.aiRecommendations,
  });

  factory HealthReportInsightDto.fromJson(Map<String, dynamic> j) {
    return HealthReportInsightDto(
      range: RangePairDto.fromJson(j['range'] ?? const {}),
      pendingCritical: PendingCriticalDto.fromJson(
        j['pending_critical'] ?? const {},
      ),
      compareToLastRange: CompareToLastRangeDto.fromJson(
        j['compare_to_last_range'] ?? const {},
      ),
      topEventType: TopEventTypeDto.fromJson(j['top_event_type'] ?? const {}),
      aiSummary: (j['ai_summary'] ?? '').toString(),
      aiRecommendations: (j['ai_recommendations'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class RangePairDto {
  final RangeDto current;
  final RangeDto previous;

  RangePairDto({required this.current, required this.previous});

  factory RangePairDto.fromJson(Map<String, dynamic> j) => RangePairDto(
    current: RangeDto.fromJson(j['current'] ?? const {}),
    previous: RangeDto.fromJson(j['previous'] ?? const {}),
  );
}

class PendingCriticalDto {
  final int dangerPendingCount;

  PendingCriticalDto({required this.dangerPendingCount});

  factory PendingCriticalDto.fromJson(Map<String, dynamic> j) =>
      PendingCriticalDto(dangerPendingCount: _asInt(j['danger_pending_count']));
}

class RangeStatsDto {
  final int total;
  final int danger;
  final int warning;
  final int normal;
  final double resolvedTrueRate;
  final double falseAlertRate;

  RangeStatsDto({
    required this.total,
    required this.danger,
    required this.warning,
    required this.normal,
    required this.resolvedTrueRate,
    required this.falseAlertRate,
  });

  factory RangeStatsDto.fromJson(Map<String, dynamic> j) => RangeStatsDto(
    total: _asInt(j['total']),
    danger: _asInt(j['danger']),
    warning: _asInt(j['warning']),
    normal: _asInt(j['normal']),
    resolvedTrueRate: _asDouble(j['resolved_true_rate']),
    falseAlertRate: _asDouble(j['false_alert_rate']),
  );
}

class RangeDeltaPctDto {
  final String totalEventsPct;
  final String dangerPct;
  final String resolvedTrueRatePct;
  final String falseAlertRatePct;

  RangeDeltaPctDto({
    required this.totalEventsPct,
    required this.dangerPct,
    required this.resolvedTrueRatePct,
    required this.falseAlertRatePct,
  });

  factory RangeDeltaPctDto.fromJson(Map<String, dynamic> j) => RangeDeltaPctDto(
    totalEventsPct: (j['total_events_pct'] ?? '').toString(),
    dangerPct: (j['danger_pct'] ?? '').toString(),
    resolvedTrueRatePct: (j['resolved_true_rate_pct'] ?? '').toString(),
    falseAlertRatePct: (j['false_alert_rate_pct'] ?? '').toString(),
  );
}

class CompareToLastRangeDto {
  final RangeStatsDto current;
  final RangeStatsDto previous;
  final RangeDeltaPctDto delta;

  CompareToLastRangeDto({
    required this.current,
    required this.previous,
    required this.delta,
  });

  factory CompareToLastRangeDto.fromJson(Map<String, dynamic> j) =>
      CompareToLastRangeDto(
        current: RangeStatsDto.fromJson(j['current'] ?? const {}),
        previous: RangeStatsDto.fromJson(j['previous'] ?? const {}),
        delta: RangeDeltaPctDto.fromJson(j['delta'] ?? const {}),
      );
}

class TopEventTypeDto {
  final String type;
  final int count;

  TopEventTypeDto({required this.type, required this.count});

  factory TopEventTypeDto.fromJson(Map<String, dynamic> j) => TopEventTypeDto(
    type: (j['type'] ?? '').toString(),
    count: _asInt(j['count']),
  );
}

/* =========================
 * Remote Data Source
 * ========================= */

class HealthReportRemoteDataSource {
  final ApiClient _api;

  HealthReportRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<HealthReportOverviewDto> overview({
    required DateTime startDay,
    required DateTime endDay,
  }) async {
    String _ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final path =
        '/health-report/overview?startDay=${_ymd(startDay)}&endDay=${_ymd(endDay)}';

    final res = await _api.get(path);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Overview failed: ${res.statusCode} ${res.body}');
    }
    final map = json.decode(res.body) as Map<String, dynamic>;
    return HealthReportOverviewDto.fromJson(map);
  }

  Future<HealthReportInsightDto> insight({
    required DateTime startDay,
    required DateTime endDay,
  }) async {
    String _ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final path =
        '/health-report/insight?startDay=${_ymd(startDay)}&endDay=${_ymd(endDay)}';

    final res = await _api.get(path);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Insight failed: ${res.statusCode} ${res.body}');
    }
    final map = json.decode(res.body) as Map<String, dynamic>;
    return HealthReportInsightDto.fromJson(map);
  }
}
