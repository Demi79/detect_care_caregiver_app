class HealthOverview {
  final String userId;
  final DateTime generatedAt;
  final HealthMetrics metrics;
  final List<HealthAlert> alerts;
  final List<HealthTrend> trends;
  final HealthSummary summary;
  final Map<String, dynamic>? filters;

  const HealthOverview({
    required this.userId,
    required this.generatedAt,
    required this.metrics,
    required this.alerts,
    required this.trends,
    required this.summary,
    this.filters,
  });

  factory HealthOverview.fromJson(Map<String, dynamic> json) {
    return HealthOverview(
      userId: json['user_id']?.toString() ?? '',
      generatedAt: DateTime.parse(
        json['generated_at'] ?? DateTime.now().toIso8601String(),
      ),
      metrics: HealthMetrics.fromJson(json['metrics'] ?? {}),
      alerts:
          (json['alerts'] as List<dynamic>?)
              ?.map(
                (alert) => HealthAlert.fromJson(alert as Map<String, dynamic>),
              )
              .toList() ??
          [],
      trends:
          (json['trends'] as List<dynamic>?)
              ?.map(
                (trend) => HealthTrend.fromJson(trend as Map<String, dynamic>),
              )
              .toList() ??
          [],
      summary: HealthSummary.fromJson(json['summary'] ?? {}),
      filters: json['filters'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'generated_at': generatedAt.toIso8601String(),
    'metrics': metrics.toJson(),
    'alerts': alerts.map((alert) => alert.toJson()).toList(),
    'trends': trends.map((trend) => trend.toJson()).toList(),
    'summary': summary.toJson(),
    'filters': filters,
  };

  HealthOverview copyWith({
    String? userId,
    DateTime? generatedAt,
    HealthMetrics? metrics,
    List<HealthAlert>? alerts,
    List<HealthTrend>? trends,
    HealthSummary? summary,
    Map<String, dynamic>? filters,
  }) {
    return HealthOverview(
      userId: userId ?? this.userId,
      generatedAt: generatedAt ?? this.generatedAt,
      metrics: metrics ?? this.metrics,
      alerts: alerts ?? this.alerts,
      trends: trends ?? this.trends,
      summary: summary ?? this.summary,
      filters: filters ?? this.filters,
    );
  }
}

class HealthMetrics {
  final int totalEvents;
  final int alertEvents;
  final int normalEvents;
  final int totalCameras;
  final int activeCameras;
  final int inactiveCameras;
  final double averageResponseTime;
  final double uptimePercentage;
  final Map<String, int> eventsByType;
  final Map<String, int> eventsByHour;

  const HealthMetrics({
    required this.totalEvents,
    required this.alertEvents,
    required this.normalEvents,
    required this.totalCameras,
    required this.activeCameras,
    required this.inactiveCameras,
    required this.averageResponseTime,
    required this.uptimePercentage,
    required this.eventsByType,
    required this.eventsByHour,
  });

  factory HealthMetrics.fromJson(Map<String, dynamic> json) {
    return HealthMetrics(
      totalEvents: json['total_events'] ?? 0,
      alertEvents: json['alert_events'] ?? 0,
      normalEvents: json['normal_events'] ?? 0,
      totalCameras: json['total_cameras'] ?? 0,
      activeCameras: json['active_cameras'] ?? 0,
      inactiveCameras: json['inactive_cameras'] ?? 0,
      averageResponseTime:
          (json['average_response_time'] as num?)?.toDouble() ?? 0.0,
      uptimePercentage: (json['uptime_percentage'] as num?)?.toDouble() ?? 0.0,
      eventsByType: Map<String, int>.from(json['events_by_type'] ?? {}),
      eventsByHour: Map<String, int>.from(json['events_by_hour'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'total_events': totalEvents,
    'alert_events': alertEvents,
    'normal_events': normalEvents,
    'total_cameras': totalCameras,
    'active_cameras': activeCameras,
    'inactive_cameras': inactiveCameras,
    'average_response_time': averageResponseTime,
    'uptime_percentage': uptimePercentage,
    'events_by_type': eventsByType,
    'events_by_hour': eventsByHour,
  };

  HealthMetrics copyWith({
    int? totalEvents,
    int? alertEvents,
    int? normalEvents,
    int? totalCameras,
    int? activeCameras,
    int? inactiveCameras,
    double? averageResponseTime,
    double? uptimePercentage,
    Map<String, int>? eventsByType,
    Map<String, int>? eventsByHour,
  }) {
    return HealthMetrics(
      totalEvents: totalEvents ?? this.totalEvents,
      alertEvents: alertEvents ?? this.alertEvents,
      normalEvents: normalEvents ?? this.normalEvents,
      totalCameras: totalCameras ?? this.totalCameras,
      activeCameras: activeCameras ?? this.activeCameras,
      inactiveCameras: inactiveCameras ?? this.inactiveCameras,
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
      uptimePercentage: uptimePercentage ?? this.uptimePercentage,
      eventsByType: eventsByType ?? this.eventsByType,
      eventsByHour: eventsByHour ?? this.eventsByHour,
    );
  }
}

class HealthAlert {
  final String id;
  final String type;
  final String severity;
  final String message;
  final DateTime timestamp;
  final String? cameraId;
  final String? eventId;
  final bool isResolved;
  final DateTime? resolvedAt;
  final Map<String, dynamic>? metadata;

  const HealthAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.cameraId,
    this.eventId,
    required this.isResolved,
    this.resolvedAt,
    this.metadata,
  });

  factory HealthAlert.fromJson(Map<String, dynamic> json) {
    return HealthAlert(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'low',
      message: json['message']?.toString() ?? '',
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      cameraId: json['camera_id']?.toString(),
      eventId: json['event_id']?.toString(),
      isResolved: json['is_resolved'] ?? false,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'severity': severity,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'camera_id': cameraId,
    'event_id': eventId,
    'is_resolved': isResolved,
    'resolved_at': resolvedAt?.toIso8601String(),
    'metadata': metadata,
  };

  HealthAlert copyWith({
    String? id,
    String? type,
    String? severity,
    String? message,
    DateTime? timestamp,
    String? cameraId,
    String? eventId,
    bool? isResolved,
    DateTime? resolvedAt,
    Map<String, dynamic>? metadata,
  }) {
    return HealthAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      cameraId: cameraId ?? this.cameraId,
      eventId: eventId ?? this.eventId,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

class HealthTrend {
  final String metric;
  final String period;
  final List<HealthTrendPoint> data;
  final double changePercentage;
  final String trend;

  const HealthTrend({
    required this.metric,
    required this.period,
    required this.data,
    required this.changePercentage,
    required this.trend,
  });

  factory HealthTrend.fromJson(Map<String, dynamic> json) {
    return HealthTrend(
      metric: json['metric']?.toString() ?? '',
      period: json['period']?.toString() ?? '7d',
      data:
          (json['data'] as List<dynamic>?)
              ?.map(
                (point) =>
                    HealthTrendPoint.fromJson(point as Map<String, dynamic>),
              )
              .toList() ??
          [],
      changePercentage: (json['change_percentage'] as num?)?.toDouble() ?? 0.0,
      trend: json['trend']?.toString() ?? 'stable',
    );
  }

  Map<String, dynamic> toJson() => {
    'metric': metric,
    'period': period,
    'data': data.map((point) => point.toJson()).toList(),
    'change_percentage': changePercentage,
    'trend': trend,
  };

  HealthTrend copyWith({
    String? metric,
    String? period,
    List<HealthTrendPoint>? data,
    double? changePercentage,
    String? trend,
  }) {
    return HealthTrend(
      metric: metric ?? this.metric,
      period: period ?? this.period,
      data: data ?? this.data,
      changePercentage: changePercentage ?? this.changePercentage,
      trend: trend ?? this.trend,
    );
  }
}

class HealthTrendPoint {
  final DateTime timestamp;
  final double value;

  const HealthTrendPoint({required this.timestamp, required this.value});

  factory HealthTrendPoint.fromJson(Map<String, dynamic> json) {
    return HealthTrendPoint(
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'value': value,
  };

  HealthTrendPoint copyWith({DateTime? timestamp, double? value}) {
    return HealthTrendPoint(
      timestamp: timestamp ?? this.timestamp,
      value: value ?? this.value,
    );
  }
}

class HealthSummary {
  final String overallStatus;
  final int totalIssues;
  final int criticalIssues;
  final int warningIssues;
  final String lastUpdated;
  final List<String> recommendations;

  const HealthSummary({
    required this.overallStatus,
    required this.totalIssues,
    required this.criticalIssues,
    required this.warningIssues,
    required this.lastUpdated,
    required this.recommendations,
  });

  factory HealthSummary.fromJson(Map<String, dynamic> json) {
    return HealthSummary(
      overallStatus: json['overall_status']?.toString() ?? 'healthy',
      totalIssues: json['total_issues'] ?? 0,
      criticalIssues: json['critical_issues'] ?? 0,
      warningIssues: json['warning_issues'] ?? 0,
      lastUpdated: json['last_updated']?.toString() ?? '',
      recommendations: List<String>.from(json['recommendations'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'overall_status': overallStatus,
    'total_issues': totalIssues,
    'critical_issues': criticalIssues,
    'warning_issues': warningIssues,
    'last_updated': lastUpdated,
    'recommendations': recommendations,
  };

  HealthSummary copyWith({
    String? overallStatus,
    int? totalIssues,
    int? criticalIssues,
    int? warningIssues,
    String? lastUpdated,
    List<String>? recommendations,
  }) {
    return HealthSummary(
      overallStatus: overallStatus ?? this.overallStatus,
      totalIssues: totalIssues ?? this.totalIssues,
      criticalIssues: criticalIssues ?? this.criticalIssues,
      warningIssues: warningIssues ?? this.warningIssues,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      recommendations: recommendations ?? this.recommendations,
    );
  }
}
