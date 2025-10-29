import 'dart:convert';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:http/http.dart' as http;

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

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<(String, Map<String, String>?)> _buildPathAndHeaders(
    String basePath,
    DateTime startDay,
    DateTime endDay,
  ) async {
    var path = '$basePath?startDay=${_ymd(startDay)}&endDay=${_ymd(endDay)}';
    String? userId = await AuthStorage.getUserId();

    if (userId == null || userId.isEmpty) {
      try {
        final token = await AuthStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          final decoded = _tryDecodeJwtPayload(token);
          final candidate =
              decoded['user_id'] as String? ?? decoded['sub'] as String?;
          if (candidate != null && candidate.isNotEmpty) {
            userId = candidate;
          }
        }
      } catch (e) {
        debugPrint('[DEBUG] health_report: JWT decode fallback failed: $e');
      }
    }

    final headers = (userId != null && userId.isNotEmpty)
        ? {'X-User-Id': userId}
        : null;
    if (userId != null && userId.isNotEmpty) {
      path = '$path&userId=${Uri.encodeComponent(userId)}';
    }
    return (path, headers);
  }

  Map<String, dynamic> _tryDecodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return {};
      final payload = parts[1];
      String normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final bytes = base64Url.decode(normalized);
      final decoded = utf8.decode(bytes);
      if (decoded.isEmpty) return {};
      final map = Map<String, dynamic>.from(
        json.decode(decoded) as Map<String, dynamic>,
      );
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<HealthReportOverviewDto> overview({
    required DateTime startDay,
    required DateTime endDay,
  }) async {
    final tuple = await _buildPathAndHeaders(
      '/health/reports/overview',
      startDay,
      endDay,
    );
    final path = tuple.$1;
    final extraHeaders = tuple.$2;

    final res = await _api.get(path, extraHeaders: extraHeaders);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Overview failed: ${res.statusCode} ${res.body}');
    }
    final map = _api.extractDataFromResponse(res) as Map<String, dynamic>;
    try {
      debugPrint(
        '[DEBUG] health-report raw high_risk_time: ${map['high_risk_time']}',
      );
    } catch (_) {}
    return HealthReportOverviewDto.fromJson(map);
  }

  Future<HealthReportInsightDto> insight({
    required DateTime startDay,
    required DateTime endDay,
  }) async {
    final tuple2 = await _buildPathAndHeaders(
      '/health/reports/insights',
      startDay,
      endDay,
    );
    final path2 = tuple2.$1;
    final extraHeaders2 = tuple2.$2;

    final res = await _api.get(path2, extraHeaders: extraHeaders2);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Insight failed: ${res.statusCode} ${res.body}');
    }
    final map = _api.extractDataFromResponse(res) as Map<String, dynamic>;
    return HealthReportInsightDto.fromJson(map);
  }

  Future<dynamic> fetchAnalystUserJsonRange({
    required String userId,
    required String from,
    required String to,
    bool includeData = true,
  }) async {
    final q = {
      'userId': userId,
      'from': from,
      'to': to,
      'includeData': includeData.toString(),
    };
    final uri = Uri.https(
      'analyst.cicca.dpdns.org',
      '/file-manage/user-json-range',
      q,
    );

    try {
      final token = await AuthStorage.getAccessToken();
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await http.get(uri, headers: headers);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Analyst fetch failed: ${res.statusCode} ${res.body}');
      }
      return json.decode(res.body);
    } catch (e) {
      debugPrint('[ANALYST] fetch error: $e');
      rethrow;
    }
  }
}
