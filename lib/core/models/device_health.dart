class DeviceHealth {
  final String deviceId;
  final String deviceType;
  final bool isOnline;
  final double? fps;
  final double? cpuUsage;
  final double? memoryUsage;
  final int? networkLatency;
  final DateTime lastSeen;
  final DateTime? lastHealthCheck;
  final List<HealthAlert> alerts;
  final Map<String, dynamic> metadata;

  const DeviceHealth({
    required this.deviceId,
    required this.deviceType,
    required this.isOnline,
    this.fps,
    this.cpuUsage,
    this.memoryUsage,
    this.networkLatency,
    required this.lastSeen,
    this.lastHealthCheck,
    this.alerts = const [],
    this.metadata = const {},
  });

  factory DeviceHealth.fromJson(Map<String, dynamic> json) {
    return DeviceHealth(
      deviceId: json['device_id']?.toString() ?? '',
      deviceType: json['device_type']?.toString() ?? 'camera',
      isOnline: json['is_online'] == true,
      fps: json['fps'] != null ? (json['fps'] as num).toDouble() : null,
      cpuUsage: json['cpu_usage'] != null
          ? (json['cpu_usage'] as num).toDouble()
          : null,
      memoryUsage: json['memory_usage'] != null
          ? (json['memory_usage'] as num).toDouble()
          : null,
      networkLatency: json['network_latency'] as int?,
      lastSeen: DateTime.parse(
        json['last_seen'] ?? DateTime.now().toIso8601String(),
      ),
      lastHealthCheck: json['last_health_check'] != null
          ? DateTime.parse(json['last_health_check'])
          : null,
      alerts:
          (json['alerts'] as List?)
              ?.map((e) => HealthAlert.fromJson(e))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'device_type': deviceType,
    'is_online': isOnline,
    'fps': fps,
    'cpu_usage': cpuUsage,
    'memory_usage': memoryUsage,
    'network_latency': networkLatency,
    'last_seen': lastSeen.toIso8601String(),
    'last_health_check': lastHealthCheck?.toIso8601String(),
    'alerts': alerts.map((e) => e.toJson()).toList(),
    'metadata': metadata,
  };

  DeviceHealth copyWith({
    String? deviceId,
    String? deviceType,
    bool? isOnline,
    double? fps,
    double? cpuUsage,
    double? memoryUsage,
    int? networkLatency,
    DateTime? lastSeen,
    DateTime? lastHealthCheck,
    List<HealthAlert>? alerts,
    Map<String, dynamic>? metadata,
  }) {
    return DeviceHealth(
      deviceId: deviceId ?? this.deviceId,
      deviceType: deviceType ?? this.deviceType,
      isOnline: isOnline ?? this.isOnline,
      fps: fps ?? this.fps,
      cpuUsage: cpuUsage ?? this.cpuUsage,
      memoryUsage: memoryUsage ?? this.memoryUsage,
      networkLatency: networkLatency ?? this.networkLatency,
      lastSeen: lastSeen ?? this.lastSeen,
      lastHealthCheck: lastHealthCheck ?? this.lastHealthCheck,
      alerts: alerts ?? this.alerts,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get hasIssues {
    return !isOnline ||
        (fps != null && fps! < 15) ||
        (cpuUsage != null && cpuUsage! > 90) ||
        (memoryUsage != null && memoryUsage! > 90) ||
        (networkLatency != null && networkLatency! > 1000);
  }
}

class HealthAlert {
  final String id;
  final String deviceId;
  final HealthAlertType type;
  final String message;
  final String severity;
  final DateTime createdAt;
  final bool resolved;
  final DateTime? resolvedAt;

  const HealthAlert({
    required this.id,
    required this.deviceId,
    required this.type,
    required this.message,
    required this.severity,
    required this.createdAt,
    this.resolved = false,
    this.resolvedAt,
  });

  factory HealthAlert.fromJson(Map<String, dynamic> json) {
    return HealthAlert(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      type: HealthAlertType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => HealthAlertType.offline,
      ),
      message: json['message']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'low',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      resolved: json['resolved'] == true,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'device_id': deviceId,
    'type': type.name,
    'message': message,
    'severity': severity,
    'created_at': createdAt.toIso8601String(),
    'resolved': resolved,
    'resolved_at': resolvedAt?.toIso8601String(),
  };
}

enum HealthAlertType {
  offline,
  lowFps,
  highCpu,
  highMemory,
  highLatency,
  connectionLost,
  hardwareFailure,
}
