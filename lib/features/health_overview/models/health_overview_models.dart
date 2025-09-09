import 'package:flutter/material.dart';

enum ActivityStatus { normal, warning, danger, unknown }

ActivityStatus parseActivityStatus(String raw) {
  switch (raw.toLowerCase()) {
    case 'normal':
      return ActivityStatus.normal;
    case 'warning':
      return ActivityStatus.warning;
    case 'danger':
      return ActivityStatus.danger;
    default:
      return ActivityStatus.unknown;
  }
}

class HealthOverviewData {
  final OverallDetectionSummary overallSummary;
  final List<DailyActivity> dailyActivities;
  final String aiSummary;

  HealthOverviewData({
    required this.overallSummary,
    required this.dailyActivities,
    required this.aiSummary,
  });

  factory HealthOverviewData.fromJson(Map<String, dynamic> json) {
    return HealthOverviewData(
      overallSummary: OverallDetectionSummary.fromJson(json),
      dailyActivities: (json['dailyActivityLog'] as List? ?? [])
          .map((item) => DailyActivity.fromJson(item))
          .toList(),
      aiSummary: json['aiSummary']?.toString() ?? '',
    );
  }
}

class OverallDetectionSummary {
  final int totalDetectionSessions;
  final int
  progressComparedToLastWeek; // positive = improved, negative = declined

  OverallDetectionSummary({
    required this.totalDetectionSessions,
    required this.progressComparedToLastWeek,
  });

  factory OverallDetectionSummary.fromJson(Map<String, dynamic> json) {
    return OverallDetectionSummary(
      totalDetectionSessions: (json['totalDetectionSessions'] is num)
          ? (json['totalDetectionSessions'] as num).toInt()
          : int.tryParse(json['totalDetectionSessions']?.toString() ?? '0') ??
                0,
      progressComparedToLastWeek: (json['progressComparedToLastWeek'] is num)
          ? (json['progressComparedToLastWeek'] as num).toInt()
          : int.tryParse(
                  json['progressComparedToLastWeek']?.toString() ?? '0',
                ) ??
                0,
    );
  }

  bool get isProgressPositive => progressComparedToLastWeek >= 0;

  String get progressStatus {
    if (progressComparedToLastWeek > 0) {
      return 'Improved';
    } else if (progressComparedToLastWeek < 0) {
      return 'Declined';
    } else {
      return 'No Change';
    }
  }
}

class DailyActivity {
  final String date;
  final ActivityStatus status;

  DailyActivity({required this.date, required this.status});

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      date: json['date']?.toString() ?? '',
      status: parseActivityStatus(json['status']?.toString() ?? ''),
    );
  }

  String get statusLabel {
    switch (status) {
      case ActivityStatus.normal:
        return 'normal';
      case ActivityStatus.warning:
        return 'warning';
      case ActivityStatus.danger:
        return 'danger';
      default:
        return 'unknown';
    }
  }

  Color get statusColor {
    switch (status) {
      case ActivityStatus.normal:
        return Colors.green;
      case ActivityStatus.warning:
        return Colors.orange;
      case ActivityStatus.danger:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
