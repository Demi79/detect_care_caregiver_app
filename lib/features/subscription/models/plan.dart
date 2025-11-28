class Plan {
  final String code;
  final String name;
  final int price;
  final int cameraQuota;
  final int retentionDays;
  final int caregiverSeats;
  final int sites;
  final int majorUpdatesMonths;
  final DateTime createdAt;
  final String storageSize;
  final bool isRecommended;

  Plan({
    required this.code,
    required this.name,
    required this.price,
    required this.cameraQuota,
    required this.retentionDays,
    required this.caregiverSeats,
    required this.sites,
    required this.majorUpdatesMonths,
    required this.createdAt,
    required this.storageSize,
    this.isRecommended = false,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    // Helper to parse ints that might be String or num or null
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    // created_at from backend can be a String, an object, or empty; handle safely
    final createdAtRaw = json['created_at'];
    DateTime createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else if (createdAtRaw is Map && createdAtRaw.containsKey('date')) {
      final dateVal = createdAtRaw['date'];
      createdAt = (dateVal is String)
          ? DateTime.tryParse(dateVal) ?? DateTime.now()
          : DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    // Handle versioned fields - prefer current_version_* fields if available
    final price = parseInt(json['current_version_price'] ?? json['price']);
    final cameraQuota = parseInt(
      json['current_version_camera_quota'] ?? json['camera_quota'],
    );
    final retentionDays = parseInt(
      json['current_version_retention_days'] ?? json['retention_days'],
    );
    final caregiverSeats = parseInt(
      json['current_version_caregiver_seats'] ?? json['caregiver_seats'],
    );
    final sites = parseInt(json['current_version_sites'] ?? json['sites']);
    final majorUpdatesMonths = parseInt(json['major_updates_months']);
    final storageSize =
        json['current_version_storage_size']?.toString() ??
        json['storage_size']?.toString();

    // Provide default storage size based on plan code if not provided
    String getDefaultStorageSize(String code) {
      switch (code) {
        case 'basic':
        case 'future-plan-test':
          return '5GB';
        case 'pro':
        case 'premium-vision-2025':
          return '50GB';
        case 'premium':
          return '100GB';
        default:
          return '10GB';
      }
    }

    return Plan(
      code: json['code'] ?? json['plan_id'] ?? '',
      name: json['name'] ?? '',
      price: price,
      cameraQuota: cameraQuota,
      retentionDays: retentionDays,
      caregiverSeats: caregiverSeats,
      sites: sites,
      majorUpdatesMonths: majorUpdatesMonths,
      createdAt: createdAt,
      storageSize: storageSize ?? getDefaultStorageSize(json['code'] ?? ''),
      isRecommended:
          json['is_recommended'] ??
          (json['code'] == 'pro' || json['code'] == 'premium-vision-2025'),
    );
  }
}
