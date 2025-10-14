class UserConsent {
  final String id;
  final String userId;
  final ConsentType type;
  final String version;
  final bool consented;
  final DateTime? consentedAt;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic>? metadata;

  const UserConsent({
    required this.id,
    required this.userId,
    required this.type,
    required this.version,
    required this.consented,
    this.consentedAt,
    this.ipAddress,
    this.userAgent,
    this.metadata,
  });

  factory UserConsent.fromJson(Map<String, dynamic> json) {
    return UserConsent(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      type: ConsentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ConsentType.privacyPolicy,
      ),
      version: json['version']?.toString() ?? '1.0',
      consented: json['consented'] == true,
      consentedAt: json['consented_at'] != null
          ? DateTime.parse(json['consented_at'])
          : null,
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'type': type.name,
    'version': version,
    'consented': consented,
    'consented_at': consentedAt?.toIso8601String(),
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'metadata': metadata,
  };

  UserConsent copyWith({
    String? id,
    String? userId,
    ConsentType? type,
    String? version,
    bool? consented,
    DateTime? consentedAt,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? metadata,
  }) {
    return UserConsent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      version: version ?? this.version,
      consented: consented ?? this.consented,
      consentedAt: consentedAt ?? this.consentedAt,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum ConsentType {
  privacyPolicy,
  termsOfService,
  dataProcessing,
  marketingCommunications,
  healthDataSharing,
}
