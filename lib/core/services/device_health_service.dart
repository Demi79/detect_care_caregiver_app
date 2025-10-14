import 'dart:async';

import 'package:detect_care_caregiver_app/core/models/device_health.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:flutter/foundation.dart';

class DeviceHealthService {
  final ApiClient _api;
  Timer? _healthCheckTimer;
  final Map<String, DeviceHealth> _deviceHealthCache = {};

  DeviceHealthService({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  void startHealthMonitoring({
    Duration checkInterval = const Duration(minutes: 5),
  }) {
    stopHealthMonitoring();

    _healthCheckTimer = Timer.periodic(checkInterval, (_) {
      checkAllDevicesHealth();
    });
  }

  void stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  Future<void> checkAllDevicesHealth() async {
    try {
      final userId = await AuthStorage.getUserId();
      if (userId == null) return;

      final devices = await _getUserDevices(userId);

      for (final device in devices) {
        final deviceId = device['id'];
        if (deviceId == null || deviceId.toString().isEmpty) {
          debugPrint(
            '⚠️ DeviceHealthService: Skipping device with null/empty ID: $device',
          );
          continue;
        }
        await checkDeviceHealth(deviceId.toString());
      }
    } catch (e) {
      AppLogger.e('Error checking devices health: $e');
    }
  }

  Future<void> checkDeviceHealth(String deviceId) async {
    try {
      final response = await _api.get('/devices/$deviceId/health');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) {
          debugPrint(
            '🚨 [DeviceHealthService] Authentication failed (401) for device $deviceId - token may be expired',
          );
          return;
        }

        debugPrint(
          'Device health API returned ${response.statusCode} for $deviceId: ${response.body}',
        );
        throw Exception('Device health fetch failed');
      }
      final decoded = _api.extractDataFromResponse(response);
      if (decoded == null || decoded is! Map) {
        debugPrint(
          'Device health: unexpected response shape for $deviceId: ${response.body}',
        );
        throw Exception('Invalid device health response');
      }
      final Map<String, dynamic> health = decoded.cast<String, dynamic>();
      final deviceHealth = DeviceHealth.fromJson(health);

      _deviceHealthCache[deviceId] = deviceHealth;

      await _checkForHealthIssues(deviceHealth);
    } catch (e) {
      debugPrint('Error checking device health for $deviceId: $e');

      final offlineAlert = HealthAlert(
        id: 'offline_${deviceId}_${DateTime.now().millisecondsSinceEpoch}',
        deviceId: deviceId,
        type: HealthAlertType.offline,
        message: 'Không thể kết nối đến thiết bị',
        severity: 'high',
        createdAt: DateTime.now(),
      );

      await _createHealthAlert(offlineAlert);
    }
  }

  Future<void> _checkForHealthIssues(DeviceHealth health) async {
    final alerts = <HealthAlert>[];

    if (health.fps != null && health.fps! < 15) {
      alerts.add(
        HealthAlert(
          id: 'low_fps_${health.deviceId}_${DateTime.now().millisecondsSinceEpoch}',
          deviceId: health.deviceId,
          type: HealthAlertType.lowFps,
          message: 'FPS thấp: ${health.fps} (dưới ngưỡng 15)',
          severity: health.fps! < 5 ? 'critical' : 'high',
          createdAt: DateTime.now(),
        ),
      );
    }

    if (health.cpuUsage != null && health.cpuUsage! > 90) {
      alerts.add(
        HealthAlert(
          id: 'high_cpu_${health.deviceId}_${DateTime.now().millisecondsSinceEpoch}',
          deviceId: health.deviceId,
          type: HealthAlertType.highCpu,
          message: 'CPU usage cao: ${health.cpuUsage}%',
          severity: 'high',
          createdAt: DateTime.now(),
        ),
      );
    }

    if (health.memoryUsage != null && health.memoryUsage! > 90) {
      alerts.add(
        HealthAlert(
          id: 'high_memory_${health.deviceId}_${DateTime.now().millisecondsSinceEpoch}',
          deviceId: health.deviceId,
          type: HealthAlertType.highMemory,
          message: 'Memory usage cao: ${health.memoryUsage}%',
          severity: 'high',
          createdAt: DateTime.now(),
        ),
      );
    }

    if (health.networkLatency != null && health.networkLatency! > 1000) {
      alerts.add(
        HealthAlert(
          id: 'high_latency_${health.deviceId}_${DateTime.now().millisecondsSinceEpoch}',
          deviceId: health.deviceId,
          type: HealthAlertType.highLatency,
          message: 'Network latency cao: ${health.networkLatency}ms',
          severity: 'medium',
          createdAt: DateTime.now(),
        ),
      );
    }

    if (!health.isOnline) {
      alerts.add(
        HealthAlert(
          id: 'offline_${health.deviceId}_${DateTime.now().millisecondsSinceEpoch}',
          deviceId: health.deviceId,
          type: HealthAlertType.offline,
          message: 'Thiết bị offline',
          severity: 'critical',
          createdAt: DateTime.now(),
        ),
      );
    }

    for (final alert in alerts) {
      await _createHealthAlert(alert);
    }
  }

  Future<void> _createHealthAlert(HealthAlert alert) async {
    try {
      await _api.post(
        '/devices/${alert.deviceId}/health-alerts',
        body: alert.toJson(),
      );
      AppLogger.i(
        'Created health alert: ${alert.type} for device ${alert.deviceId}',
      );
    } catch (e) {
      AppLogger.e('Error creating health alert: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getUserDevices(String userId) async {
    try {
      final response = await _api.get('/users/$userId/devices');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) {
          debugPrint(
            '🚨 [DeviceHealthService] Authentication failed (401) for user $userId - token may be expired',
          );
          return [];
        }

        debugPrint(
          'User devices API returned ${response.statusCode} for $userId: ${response.body}',
        );
        return [];
      }
      final decoded = _api.extractDataFromResponse(response);
      if (decoded == null) return [];

      dynamic data;
      if (decoded is Map && decoded.containsKey('data')) {
        data = decoded['data'];
        debugPrint('📦 DeviceHealthService: Data extracted from response.data');
      } else if (decoded is Map && decoded.containsKey('devices')) {
        data = decoded['devices'];
        debugPrint(
          '📦 DeviceHealthService: Devices extracted from response.devices',
        );
      } else {
        data = decoded;
        debugPrint(
          '📦 DeviceHealthService: Data extracted directly from response',
        );
      }

      if (data is List) {
        debugPrint(
          '📦 DeviceHealthService: Processing list of devices directly',
        );
        return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
      } else if (data is Map && data['devices'] is List) {
        debugPrint(
          '📦 DeviceHealthService: Processing devices from data.devices',
        );
        return List<Map<String, dynamic>>.from(data['devices']);
      } else if (data is Map && data['items'] is List) {
        debugPrint(
          '📦 DeviceHealthService: Processing devices from data.items',
        );
        return List<Map<String, dynamic>>.from(data['items']);
      } else {
        debugPrint(
          'User devices: unexpected data type: ${data.runtimeType}, data: $data',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Error getting user devices: $e');
      return [];
    }
  }

  DeviceHealth? getDeviceHealth(String deviceId) {
    return _deviceHealthCache[deviceId];
  }

  List<DeviceHealth> getAllDeviceHealth() {
    return _deviceHealthCache.values.toList();
  }

  List<DeviceHealth> getDevicesWithIssues() {
    return _deviceHealthCache.values
        .where((health) => health.hasIssues)
        .toList();
  }

  Future<List<HealthAlert>> getDeviceAlerts(
    String deviceId, {
    bool unresolvedOnly = true,
    int limit = 50,
  }) async {
    try {
      final response = await _api.get(
        '/devices/$deviceId/health-alerts',
        query: {
          'unresolved_only': unresolvedOnly.toString(),
          'limit': limit.toString(),
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Device alerts API returned ${response.statusCode} for $deviceId: ${response.body}',
        );
        return [];
      }
      final decoded = _api.extractDataFromResponse(response);
      if (decoded == null) return [];
      final List data = decoded is List
          ? decoded
          : (decoded is Map && decoded.containsKey('items')
                ? decoded['items'] as List
                : []);
      return data
          .map((e) => HealthAlert.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error getting device alerts: $e');
      return [];
    }
  }

  Future<void> resolveAlert(String deviceId, String alertId) async {
    try {
      await _api.patch(
        '/devices/$deviceId/health-alerts/$alertId',
        body: {
          'resolved': true,
          'resolved_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      AppLogger.e('Error resolving alert: $e');
      rethrow;
    }
  }

  void dispose() {
    stopHealthMonitoring();
    _deviceHealthCache.clear();
  }
}
