class Plan {
  final String id;
  final String code;
  final String name;
  final String? description;
  final int tier;
  final int cameraQuota;
  final int retentionDays;
  final int caregiverSeats;
  final int sites;
  final int majorUpdatesMonths;
  final String storageSize;
  final String price;
  final String currency;
  final String status;
  final bool isRecommended;
  final bool isCurrent;
  final String version;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final DateTime? createdAt;
  final int? versionCount;
  final List<Plan>? versions;
  final Map<String, dynamic>? featureFlags;
  final String? slaTier;
  final String? successorPlanCode;

  const Plan({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.tier,
    required this.cameraQuota,
    required this.retentionDays,
    required this.caregiverSeats,
    required this.sites,
    required this.majorUpdatesMonths,
    required this.storageSize,
    required this.price,
    required this.currency,
    required this.status,
    required this.isRecommended,
    required this.isCurrent,
    required this.version,
    this.effectiveFrom,
    this.effectiveTo,
    this.createdAt,
    this.versionCount,
    this.versions,
    this.featureFlags,
    this.slaTier,
    this.successorPlanCode,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      tier: json['tier'] ?? 1,
      cameraQuota: json['camera_quota'] ?? 0,
      retentionDays: json['retention_days'] ?? 0,
      caregiverSeats: json['caregiver_seats'] ?? 0,
      sites: json['sites'] ?? 0,
      majorUpdatesMonths: json['major_updates_months'] ?? 0,
      storageSize: json['storage_size']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      currency: json['currency']?.toString() ?? 'VND',
      status: json['status']?.toString() ?? 'available',
      isRecommended: json['is_recommended'] ?? false,
      isCurrent: json['is_current'] ?? false,
      version: json['version']?.toString() ?? '1.0',
      effectiveFrom: json['effective_from'] != null
          ? DateTime.parse(json['effective_from'])
          : null,
      effectiveTo: json['effective_to'] != null
          ? DateTime.parse(json['effective_to'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      versionCount: json['version_count'],
      versions: json['versions'] != null
          ? (json['versions'] as List).map((v) => Plan.fromJson(v)).toList()
          : null,
      featureFlags: json['feature_flags'] as Map<String, dynamic>?,
      slaTier: json['sla_tier']?.toString(),
      successorPlanCode: json['successor_plan_code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'description': description,
    'tier': tier,
    'camera_quota': cameraQuota,
    'retention_days': retentionDays,
    'caregiver_seats': caregiverSeats,
    'sites': sites,
    'major_updates_months': majorUpdatesMonths,
    'storage_size': storageSize,
    'price': price,
    'currency': currency,
    'status': status,
    'is_recommended': isRecommended,
    'is_current': isCurrent,
    'version': version,
    'effective_from': effectiveFrom?.toIso8601String(),
    'effective_to': effectiveTo?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'version_count': versionCount,
    'versions': versions?.map((v) => v.toJson()).toList(),
    'feature_flags': featureFlags,
    'sla_tier': slaTier,
    'successor_plan_code': successorPlanCode,
  };

  Plan copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    int? tier,
    int? cameraQuota,
    int? retentionDays,
    int? caregiverSeats,
    int? sites,
    int? majorUpdatesMonths,
    String? storageSize,
    String? price,
    String? currency,
    String? status,
    bool? isRecommended,
    bool? isCurrent,
    String? version,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    DateTime? createdAt,
    int? versionCount,
    List<Plan>? versions,
    Map<String, dynamic>? featureFlags,
    String? slaTier,
    String? successorPlanCode,
  }) {
    return Plan(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      tier: tier ?? this.tier,
      cameraQuota: cameraQuota ?? this.cameraQuota,
      retentionDays: retentionDays ?? this.retentionDays,
      caregiverSeats: caregiverSeats ?? this.caregiverSeats,
      sites: sites ?? this.sites,
      majorUpdatesMonths: majorUpdatesMonths ?? this.majorUpdatesMonths,
      storageSize: storageSize ?? this.storageSize,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      isRecommended: isRecommended ?? this.isRecommended,
      isCurrent: isCurrent ?? this.isCurrent,
      version: version ?? this.version,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      createdAt: createdAt ?? this.createdAt,
      versionCount: versionCount ?? this.versionCount,
      versions: versions ?? this.versions,
      featureFlags: featureFlags ?? this.featureFlags,
      slaTier: slaTier ?? this.slaTier,
      successorPlanCode: successorPlanCode ?? this.successorPlanCode,
    );
  }

  bool get isActive => status == 'available';
  bool get isExpired =>
      effectiveTo != null && DateTime.now().isAfter(effectiveTo!);
  double get priceAsDouble => double.tryParse(price) ?? 0.0;
  int get storageSizeGb {
    final match = RegExp(r'(\d+)').firstMatch(storageSize);
    return match != null ? int.parse(match.group(1)!) : 0;
  }
}
