class AuditEvent {
  final String id;
  final String userId;
  final AuditEventType eventType;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String? ipAddress;
  final String? userAgent;
  final String? sessionId;

  const AuditEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.description,
    required this.metadata,
    required this.timestamp,
    this.ipAddress,
    this.userAgent,
    this.sessionId,
  });

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      eventType: AuditEventType.values.firstWhere(
        (e) => e.name == json['event_type'],
        orElse: () => AuditEventType.other,
      ),
      description: json['description']?.toString() ?? '',
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent']?.toString(),
      sessionId: json['session_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'event_type': eventType.name,
    'description': description,
    'metadata': metadata,
    'timestamp': timestamp.toIso8601String(),
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'session_id': sessionId,
  };
}

enum AuditEventType {
  // Profile events
  profileCreated,
  profileUpdated,
  profileDeleted,

  // Invitation events
  invitationSent,
  invitationAccepted,
  invitationRejected,
  invitationRevoked,

  // Permission events
  permissionGranted,
  permissionRevoked,
  permissionUpdated,

  // Consent events
  consentGiven,
  consentRevoked,
  consentUpdated,

  // Device events
  deviceAdded,
  deviceRemoved,
  deviceUpdated,

  // Alert events
  alertCreated,
  alertAcknowledged,
  alertEscalated,

  // Authentication events
  loginSuccess,
  loginFailed,
  logout,

  // Other events
  other,
}
