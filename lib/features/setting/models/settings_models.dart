enum ImageQuality { low, medium, high }

ImageQuality imageQualityFromJson(String? v) {
  switch ((v ?? '').toLowerCase()) {
    case 'low':
      return ImageQuality.low;
    case 'high':
      return ImageQuality.high;
    default:
      return ImageQuality.medium;
  }
}

String imageQualityToJson(ImageQuality q) {
  switch (q) {
    case ImageQuality.low:
      return 'low';
    case ImageQuality.medium:
      return 'medium';
    case ImageQuality.high:
      return 'high';
  }
}

class NotificationSettings {
  final bool pushEnabled;
  final bool dangerOnly;
  final bool vibrate;
  const NotificationSettings({
    required this.pushEnabled,
    required this.dangerOnly,
    required this.vibrate,
  });
  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? dangerOnly,
    bool? vibrate,
  }) => NotificationSettings(
    pushEnabled: pushEnabled ?? this.pushEnabled,
    dangerOnly: dangerOnly ?? this.dangerOnly,
    vibrate: vibrate ?? this.vibrate,
  );
  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        pushEnabled: (json['pushEnabled'] ?? true) == true,
        dangerOnly: (json['dangerOnly'] ?? false) == true,
        vibrate: (json['vibrate'] ?? true) == true,
      );
  Map<String, dynamic> toJson() => {
    'pushEnabled': pushEnabled,
    'dangerOnly': dangerOnly,
    'vibrate': vibrate,
  };
}

class ImageSettings {
  final ImageQuality quality;
  final bool autoUpload;
  final bool wifiOnly;
  const ImageSettings({
    required this.quality,
    required this.autoUpload,
    required this.wifiOnly,
  });
  ImageSettings copyWith({
    ImageQuality? quality,
    bool? autoUpload,
    bool? wifiOnly,
  }) => ImageSettings(
    quality: quality ?? this.quality,
    autoUpload: autoUpload ?? this.autoUpload,
    wifiOnly: wifiOnly ?? this.wifiOnly,
  );
  factory ImageSettings.fromJson(Map<String, dynamic> json) => ImageSettings(
    quality: imageQualityFromJson(json['quality']?.toString()),
    autoUpload: (json['autoUpload'] ?? false) == true,
    wifiOnly: (json['wifiOnly'] ?? true) == true,
  );
  Map<String, dynamic> toJson() => {
    'quality': imageQualityToJson(quality),
    'autoUpload': autoUpload,
    'wifiOnly': wifiOnly,
  };
}

class EmergencyContact {
  final String name;
  final String phone;
  final String relation;
  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });
  EmergencyContact copyWith({String? name, String? phone, String? relation}) =>
      EmergencyContact(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        relation: relation ?? this.relation,
      );
  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        relation: json['relation']?.toString() ?? '',
      );
  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'relation': relation,
  };
}

class AppSettings {
  final String userId;
  final NotificationSettings notification;
  final ImageSettings image;
  final List<EmergencyContact> contacts;
  const AppSettings({
    required this.userId,
    required this.notification,
    required this.image,
    required this.contacts,
  });
  AppSettings copyWith({
    String? userId,
    NotificationSettings? notification,
    ImageSettings? image,
    List<EmergencyContact>? contacts,
  }) => AppSettings(
    userId: userId ?? this.userId,
    notification: notification ?? this.notification,
    image: image ?? this.image,
    contacts: contacts ?? this.contacts,
  );
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final list = (json['contacts'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return AppSettings(
      userId: json['userId']?.toString() ?? '',
      notification: NotificationSettings.fromJson(
        (json['notification'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      image: ImageSettings.fromJson(
        (json['image'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      contacts: list.map(EmergencyContact.fromJson).toList(),
    );
  }
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'notification': notification.toJson(),
    'image': image.toJson(),
    'contacts': contacts.map((e) => e.toJson()).toList(),
  };
}
