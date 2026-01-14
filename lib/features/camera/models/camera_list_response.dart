import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';

class CameraPagination {
  final int? total;
  final int? page;
  final int? limit;
  final int? totalPages;
  final bool? hasNext;
  final bool? hasPrev;

  const CameraPagination({
    this.total,
    this.page,
    this.limit,
    this.totalPages,
    this.hasNext,
    this.hasPrev,
  });

  factory CameraPagination.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CameraPagination();
    return CameraPagination(
      total: _parseInt(json['total']),
      page: _parseInt(json['page']),
      limit: _parseInt(json['limit']),
      totalPages: _parseInt(json['totalPages']),
      hasNext: _parseBool(json['hasNext']),
      hasPrev: _parseBool(json['hasPrev']),
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'page': page,
    'limit': limit,
    'totalPages': totalPages,
    'hasNext': hasNext,
    'hasPrev': hasPrev,
  };
}

class CameraListResponse {
  final List<CameraEntry> data;
  final CameraPagination? pagination;
  final String? message;
  final DateTime? timestamp;

  const CameraListResponse({
    required this.data,
    this.pagination,
    this.message,
    this.timestamp,
  });

  factory CameraListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final list = rawData is List
        ? rawData
        : rawData == null
        ? <dynamic>[]
        : [rawData];

    return CameraListResponse(
      data: list
          .whereType<Map<String, dynamic>>()
          .map(CameraEntry.fromJson)
          .toList(),
      pagination: CameraPagination.fromJson(
        json['pagination'] as Map<String, dynamic>?,
      ),
      message: json['message']?.toString(),
      timestamp: _parseDate(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() => {
    'data': data.map((e) => e.toJson()).toList(),
    'pagination': pagination?.toJson(),
    'message': message,
    'timestamp': timestamp?.toIso8601String(),
  };
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

bool? _parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  final str = value.toString().toLowerCase();
  if (str == 'true') return true;
  if (str == 'false') return false;
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
