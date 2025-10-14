import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/core/models/audit_event.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class AuditService {
  final ApiClient _api;
  final StreamController<AuditEvent> _auditStreamController =
      StreamController.broadcast();

  AuditService({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Stream<AuditEvent> get auditEvents => _auditStreamController.stream;

  Future<void> logEvent({
    required String userId,
    required AuditEventType eventType,
    required String description,
    Map<String, dynamic> metadata = const {},
    String? ipAddress,
    String? userAgent,
    String? sessionId,
  }) async {
    final event = AuditEvent(
      id: '',
      userId: userId,
      eventType: eventType,
      description: description,
      metadata: metadata,
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      userAgent: userAgent,
      sessionId: sessionId,
    );

    try {
      final res = await _api.post('/audit/events', body: event.toJson());
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
          'AuditService.logEvent failed: ${res.statusCode} ${res.body}',
        );
        _auditStreamController.add(event);
        return;
      }
      final decoded = _api.extractDataFromResponse(res);
      if (decoded == null || decoded is! Map) {
        debugPrint('AuditService: unexpected response shape: ${res.body}');
        _auditStreamController.add(event);
        return;
      }
      final createdEvent = AuditEvent.fromJson(decoded as Map<String, dynamic>);

      _auditStreamController.add(createdEvent);

      AppLogger.i('Audit event logged: ${eventType.name} - $description');
    } catch (e) {
      AppLogger.e('Error logging audit event: $e');

      _auditStreamController.add(event);
    }
  }

  Future<void> logProfileUpdate(
    String userId,
    Map<String, dynamic> changes,
  ) async {
    await logEvent(
      userId: userId,
      eventType: AuditEventType.profileUpdated,
      description: 'Profile updated',
      metadata: {'changes': changes},
    );
  }

  Future<void> logInvitationSent(
    String customerId,
    String caregiverId,
    String caregiverEmail,
  ) async {
    await logEvent(
      userId: customerId,
      eventType: AuditEventType.invitationSent,
      description: 'Invitation sent to caregiver',
      metadata: {
        'caregiver_id': caregiverId,
        'caregiver_email': caregiverEmail,
      },
    );
  }

  Future<void> logInvitationAccepted(
    String customerId,
    String invitationId,
    String caregiverId,
  ) async {
    await logEvent(
      userId: customerId,
      eventType: AuditEventType.invitationAccepted,
      description: 'Invitation accepted by caregiver',
      metadata: {'invitation_id': invitationId, 'caregiver_id': caregiverId},
    );
  }

  Future<void> logInvitationRejected(
    String customerId,
    String invitationId,
    String caregiverId,
    String? reason,
  ) async {
    await logEvent(
      userId: customerId,
      eventType: AuditEventType.invitationRejected,
      description: 'Invitation rejected by caregiver',
      metadata: {
        'invitation_id': invitationId,
        'caregiver_id': caregiverId,
        'reason': reason,
      },
    );
  }

  Future<void> logInvitationRevoked(
    String customerId,
    String invitationId,
    String caregiverId,
  ) async {
    await logEvent(
      userId: customerId,
      eventType: AuditEventType.invitationRevoked,
      description: 'Invitation revoked',
      metadata: {'invitation_id': invitationId, 'caregiver_id': caregiverId},
    );
  }

  Future<void> logConsentGiven(
    String userId,
    String consentType,
    String version,
  ) async {
    await logEvent(
      userId: userId,
      eventType: AuditEventType.consentGiven,
      description: 'Consent given for $consentType',
      metadata: {'consent_type': consentType, 'version': version},
    );
  }

  Future<void> logConsentRevoked(String userId, String consentType) async {
    await logEvent(
      userId: userId,
      eventType: AuditEventType.consentRevoked,
      description: 'Consent revoked for $consentType',
      metadata: {'consent_type': consentType},
    );
  }

  Future<void> logDeviceAdded(
    String userId,
    String deviceId,
    String deviceType,
  ) async {
    await logEvent(
      userId: userId,
      eventType: AuditEventType.deviceAdded,
      description: 'Device added',
      metadata: {'device_id': deviceId, 'device_type': deviceType},
    );
  }

  Future<void> logAlertCreated(
    String userId,
    String alertId,
    String severity,
  ) async {
    await logEvent(
      userId: userId,
      eventType: AuditEventType.alertCreated,
      description: 'Alert created',
      metadata: {'alert_id': alertId, 'severity': severity},
    );
  }

  Future<void> logAlertAcknowledged(String userId, String alertId) async {
    await logEvent(
      userId: userId,
      eventType: AuditEventType.alertAcknowledged,
      description: 'Alert acknowledged',
      metadata: {'alert_id': alertId},
    );
  }

  Future<void> logLogin(
    String userId,
    bool success, {
    String? failureReason,
  }) async {
    await logEvent(
      userId: userId,
      eventType: success
          ? AuditEventType.loginSuccess
          : AuditEventType.loginFailed,
      description: success ? 'Login successful' : 'Login failed',
      metadata: success ? {} : {'failure_reason': failureReason},
    );
  }

  Future<void> logLogout(String userId) async {
    await logEvent(
      userId: userId,
      eventType: AuditEventType.logout,
      description: 'User logged out',
    );
  }

  Future<List<AuditEvent>> getAuditEvents({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    AuditEventType? eventType,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final query = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (startDate != null) query['start_date'] = startDate.toIso8601String();
      if (endDate != null) query['end_date'] = endDate.toIso8601String();
      if (eventType != null) query['event_type'] = eventType.name;

      final res = await _api.get('/users/$userId/audit-events', query: query);
      final Map<String, dynamic> response = _api.decodeResponseBody(res);
      final dynamic items = response.containsKey('data')
          ? response['data']
          : response;
      final list = (items is List) ? items : [];
      return list
          .map((e) => AuditEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error getting audit events: $e');
      return [];
    }
  }

  Future<Map<String, int>> getAuditSummary(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = <String, String>{};
      if (startDate != null) query['start_date'] = startDate.toIso8601String();
      if (endDate != null) query['end_date'] = endDate.toIso8601String();

      final res = await _api.get('/users/$userId/audit-summary', query: query);
      final Map<String, dynamic> response = _api.decodeResponseBody(res);
      final dynamic mapData = response.containsKey('data')
          ? response['data']
          : response;
      return Map<String, int>.from(
        (mapData as Map).map((k, v) => MapEntry(k.toString(), v as int)),
      );
    } catch (e) {
      AppLogger.e('Error getting audit summary: $e');
      return {};
    }
  }

  void dispose() {
    _auditStreamController.close();
  }
}
