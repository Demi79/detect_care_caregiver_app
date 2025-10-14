class ImageSettings {
  final String monitoringMode;
  final String duration;
  final String frameCount;
  final String imageQuality;
  final bool enableImageSaving;
  final int normalRetentionDays;
  final int alertRetentionDays;

  const ImageSettings({
    required this.monitoringMode,
    required this.duration,
    required this.frameCount,
    required this.imageQuality,
    required this.enableImageSaving,
    required this.normalRetentionDays,
    required this.alertRetentionDays,
  });

  Map<String, dynamic> toJson() {
    return {
      'monitoring_mode': monitoringMode,
      'duration': duration,
      'frame_count': frameCount,
      'image_quality': imageQuality,
      'enable_image_saving': enableImageSaving,
      'normal_retention_days': normalRetentionDays,
      'alert_retention_days': alertRetentionDays,
    };
  }

  factory ImageSettings.fromJson(Map<String, dynamic> json) {
    return ImageSettings(
      monitoringMode: json['monitoring_mode'] ?? 'Giám sát nâng cao',
      duration: json['duration'] ?? '30 minute',
      frameCount: json['frame_count'] ?? '10 frame',
      imageQuality: json['image_quality'] ?? 'Medium (1080p)',
      enableImageSaving: json['enable_image_saving'] ?? true,
      normalRetentionDays: json['normal_retention_days'] ?? 30,
      alertRetentionDays: json['alert_retention_days'] ?? 90,
    );
  }

  ImageSettings copyWith({
    String? monitoringMode,
    String? duration,
    String? frameCount,
    String? imageQuality,
    bool? enableImageSaving,
    int? normalRetentionDays,
    int? alertRetentionDays,
  }) {
    return ImageSettings(
      monitoringMode: monitoringMode ?? this.monitoringMode,
      duration: duration ?? this.duration,
      frameCount: frameCount ?? this.frameCount,
      imageQuality: imageQuality ?? this.imageQuality,
      enableImageSaving: enableImageSaving ?? this.enableImageSaving,
      normalRetentionDays: normalRetentionDays ?? this.normalRetentionDays,
      alertRetentionDays: alertRetentionDays ?? this.alertRetentionDays,
    );
  }
}

class AlertSettings {
  final bool masterNotifications;
  final bool appNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool callNotifications;
  final bool deviceAlerts;

  const AlertSettings({
    required this.masterNotifications,
    required this.appNotifications,
    required this.emailNotifications,
    required this.smsNotifications,
    required this.callNotifications,
    required this.deviceAlerts,
  });

  Map<String, dynamic> toJson() {
    return {
      'master_notifications': masterNotifications,
      'app_notifications': appNotifications,
      'email_notifications': emailNotifications,
      'sms_notifications': smsNotifications,
      'call_notifications': callNotifications,
      'device_alerts': deviceAlerts,
    };
  }

  factory AlertSettings.fromJson(Map<String, dynamic> json) {
    return AlertSettings(
      masterNotifications: json['master_notifications'] ?? true,
      appNotifications: json['app_notifications'] ?? true,
      emailNotifications: json['email_notifications'] ?? false,
      smsNotifications: json['sms_notifications'] ?? false,
      callNotifications: json['call_notifications'] ?? false,
      deviceAlerts: json['device_alerts'] ?? false,
    );
  }

  AlertSettings copyWith({
    bool? masterNotifications,
    bool? appNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? callNotifications,
    bool? deviceAlerts,
  }) {
    return AlertSettings(
      masterNotifications: masterNotifications ?? this.masterNotifications,
      appNotifications: appNotifications ?? this.appNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      callNotifications: callNotifications ?? this.callNotifications,
      deviceAlerts: deviceAlerts ?? this.deviceAlerts,
    );
  }
}

class UserSettings {
  final String userId;
  final AppearanceSettings appearance;
  final NotificationSettings notifications;
  final DisplaySettings display;
  final PrivacySettings privacy;
  final Map<String, dynamic> customSettings;
  final DateTime updatedAt;

  const UserSettings({
    required this.userId,
    required this.appearance,
    required this.notifications,
    required this.display,
    required this.privacy,
    required this.customSettings,
    required this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      userId: json['user_id']?.toString() ?? '',
      appearance: AppearanceSettings.fromJson(json['appearance'] ?? {}),
      notifications: NotificationSettings.fromJson(json['notifications'] ?? {}),
      display: DisplaySettings.fromJson(json['display'] ?? {}),
      privacy: PrivacySettings.fromJson(json['privacy'] ?? {}),
      customSettings: Map<String, dynamic>.from(json['custom_settings'] ?? {}),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'appearance': appearance.toJson(),
    'notifications': notifications.toJson(),
    'display': display.toJson(),
    'privacy': privacy.toJson(),
    'custom_settings': customSettings,
    'updated_at': updatedAt.toIso8601String(),
  };

  UserSettings copyWith({
    String? userId,
    AppearanceSettings? appearance,
    NotificationSettings? notifications,
    DisplaySettings? display,
    PrivacySettings? privacy,
    Map<String, dynamic>? customSettings,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      appearance: appearance ?? this.appearance,
      notifications: notifications ?? this.notifications,
      display: display ?? this.display,
      privacy: privacy ?? this.privacy,
      customSettings: customSettings ?? this.customSettings,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AppearanceSettings {
  final String theme;
  final String fontFamily;
  final int fontSize;
  final String language;
  final bool highContrast;
  final String colorScheme;

  const AppearanceSettings({
    required this.theme,
    required this.fontFamily,
    required this.fontSize,
    required this.language,
    required this.highContrast,
    required this.colorScheme,
  });

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    return AppearanceSettings(
      theme: json['theme']?.toString() ?? 'light',
      fontFamily: json['font_family']?.toString() ?? 'Roboto',
      fontSize: json['font_size'] ?? 14,
      language: json['language']?.toString() ?? 'vi',
      highContrast: json['high_contrast'] ?? false,
      colorScheme: json['color_scheme']?.toString() ?? 'default',
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': theme,
    'font_family': fontFamily,
    'font_size': fontSize,
    'language': language,
    'high_contrast': highContrast,
    'color_scheme': colorScheme,
  };

  AppearanceSettings copyWith({
    String? theme,
    String? fontFamily,
    int? fontSize,
    String? language,
    bool? highContrast,
    String? colorScheme,
  }) {
    return AppearanceSettings(
      theme: theme ?? this.theme,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      language: language ?? this.language,
      highContrast: highContrast ?? this.highContrast,
      colorScheme: colorScheme ?? this.colorScheme,
    );
  }
}

class NotificationSettings {
  final bool masterNotifications;
  final bool appNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool pushNotifications;
  final bool marketingEmails;
  final bool securityEmails;
  final bool systemEmails;
  final Map<String, bool> eventTypes;

  const NotificationSettings({
    required this.masterNotifications,
    required this.appNotifications,
    required this.emailNotifications,
    required this.smsNotifications,
    required this.pushNotifications,
    required this.marketingEmails,
    required this.securityEmails,
    required this.systemEmails,
    required this.eventTypes,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      masterNotifications: json['master_notifications'] ?? true,
      appNotifications: json['app_notifications'] ?? true,
      emailNotifications: json['email_notifications'] ?? true,
      smsNotifications: json['sms_notifications'] ?? false,
      pushNotifications: json['push_notifications'] ?? true,
      marketingEmails: json['marketing_emails'] ?? false,
      securityEmails: json['security_emails'] ?? true,
      systemEmails: json['system_emails'] ?? true,
      eventTypes: Map<String, bool>.from(json['event_types'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'master_notifications': masterNotifications,
    'app_notifications': appNotifications,
    'email_notifications': emailNotifications,
    'sms_notifications': smsNotifications,
    'push_notifications': pushNotifications,
    'marketing_emails': marketingEmails,
    'security_emails': securityEmails,
    'system_emails': systemEmails,
    'event_types': eventTypes,
  };

  NotificationSettings copyWith({
    bool? masterNotifications,
    bool? appNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? pushNotifications,
    bool? marketingEmails,
    bool? securityEmails,
    bool? systemEmails,
    Map<String, bool>? eventTypes,
  }) {
    return NotificationSettings(
      masterNotifications: masterNotifications ?? this.masterNotifications,
      appNotifications: appNotifications ?? this.appNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      marketingEmails: marketingEmails ?? this.marketingEmails,
      securityEmails: securityEmails ?? this.securityEmails,
      systemEmails: systemEmails ?? this.systemEmails,
      eventTypes: eventTypes ?? this.eventTypes,
    );
  }
}

class DisplaySettings {
  final String dateFormat;
  final String timeFormat;
  final String timezone;
  final int itemsPerPage;
  final bool showTooltips;
  final bool compactView;
  final List<String> defaultColumns;

  const DisplaySettings({
    required this.dateFormat,
    required this.timeFormat,
    required this.timezone,
    required this.itemsPerPage,
    required this.showTooltips,
    required this.compactView,
    required this.defaultColumns,
  });

  factory DisplaySettings.fromJson(Map<String, dynamic> json) {
    return DisplaySettings(
      dateFormat: json['date_format']?.toString() ?? 'DD/MM/YYYY',
      timeFormat: json['time_format']?.toString() ?? 'HH:mm',
      timezone: json['timezone']?.toString() ?? 'Asia/Ho_Chi_Minh',
      itemsPerPage: json['items_per_page'] ?? 20,
      showTooltips: json['show_tooltips'] ?? true,
      compactView: json['compact_view'] ?? false,
      defaultColumns: List<String>.from(json['default_columns'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'date_format': dateFormat,
    'time_format': timeFormat,
    'timezone': timezone,
    'items_per_page': itemsPerPage,
    'show_tooltips': showTooltips,
    'compact_view': compactView,
    'default_columns': defaultColumns,
  };

  DisplaySettings copyWith({
    String? dateFormat,
    String? timeFormat,
    String? timezone,
    int? itemsPerPage,
    bool? showTooltips,
    bool? compactView,
    List<String>? defaultColumns,
  }) {
    return DisplaySettings(
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      timezone: timezone ?? this.timezone,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      showTooltips: showTooltips ?? this.showTooltips,
      compactView: compactView ?? this.compactView,
      defaultColumns: defaultColumns ?? this.defaultColumns,
    );
  }
}

class PrivacySettings {
  final bool dataCollection;
  final bool analyticsTracking;
  final bool crashReporting;
  final bool locationTracking;
  final String dataRetentionPeriod;
  final bool shareHealthData;
  final bool shareUsageData;

  const PrivacySettings({
    required this.dataCollection,
    required this.analyticsTracking,
    required this.crashReporting,
    required this.locationTracking,
    required this.dataRetentionPeriod,
    required this.shareHealthData,
    required this.shareUsageData,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      dataCollection: json['data_collection'] ?? true,
      analyticsTracking: json['analytics_tracking'] ?? false,
      crashReporting: json['crash_reporting'] ?? true,
      locationTracking: json['location_tracking'] ?? false,
      dataRetentionPeriod:
          json['data_retention_period']?.toString() ?? '1_year',
      shareHealthData: json['share_health_data'] ?? false,
      shareUsageData: json['share_usage_data'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'data_collection': dataCollection,
    'analytics_tracking': analyticsTracking,
    'crash_reporting': crashReporting,
    'location_tracking': locationTracking,
    'data_retention_period': dataRetentionPeriod,
    'share_health_data': shareHealthData,
    'share_usage_data': shareUsageData,
  };

  PrivacySettings copyWith({
    bool? dataCollection,
    bool? analyticsTracking,
    bool? crashReporting,
    bool? locationTracking,
    String? dataRetentionPeriod,
    bool? shareHealthData,
    bool? shareUsageData,
  }) {
    return PrivacySettings(
      dataCollection: dataCollection ?? this.dataCollection,
      analyticsTracking: analyticsTracking ?? this.analyticsTracking,
      crashReporting: crashReporting ?? this.crashReporting,
      locationTracking: locationTracking ?? this.locationTracking,
      dataRetentionPeriod: dataRetentionPeriod ?? this.dataRetentionPeriod,
      shareHealthData: shareHealthData ?? this.shareHealthData,
      shareUsageData: shareUsageData ?? this.shareUsageData,
    );
  }
}
