class SharedPermissions {
  final bool streamView;
  final bool alertRead;
  final bool alertAck;
  final int logAccessDays;
  final int reportAccessDays;
  final List<String> notificationChannel; // ["push","sms",...]
  final bool profileView;

  const SharedPermissions({
    required this.streamView,
    required this.alertRead,
    required this.alertAck,
    required this.logAccessDays,
    required this.reportAccessDays,
    required this.notificationChannel,
    required this.profileView,
  });

  factory SharedPermissions.fromJson(Map<String, dynamic> json) {
    return SharedPermissions(
      streamView: json['stream_view'] == true,
      alertRead: json['alert_read'] == true,
      alertAck: json['alert_ack'] == true,
      logAccessDays: (json['log_access_days'] ?? 0) as int,
      reportAccessDays: (json['report_access_days'] ?? 0) as int,
      notificationChannel:
          (json['notification_channel'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      profileView: json['profile_view'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'stream_view': streamView,
    'alert_read': alertRead,
    'alert_ack': alertAck,
    'log_access_days': logAccessDays,
    'report_access_days': reportAccessDays,
    'notification_channel': notificationChannel,
    'profile_view': profileView,
  };

  SharedPermissions copyWith({
    bool? streamView,
    bool? alertRead,
    bool? alertAck,
    int? logAccessDays,
    int? reportAccessDays,
    List<String>? notificationChannel,
    bool? profileView,
  }) {
    return SharedPermissions(
      streamView: streamView ?? this.streamView,
      alertRead: alertRead ?? this.alertRead,
      alertAck: alertAck ?? this.alertAck,
      logAccessDays: logAccessDays ?? this.logAccessDays,
      reportAccessDays: reportAccessDays ?? this.reportAccessDays,
      notificationChannel: notificationChannel ?? this.notificationChannel,
      profileView: profileView ?? this.profileView,
    );
  }
}
