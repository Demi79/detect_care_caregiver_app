class RetrySettings {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final List<String> escalationChannels; // ['sms', 'call', 'emergency_contact']
  final Duration escalationDelay;

  const RetrySettings({
    required this.maxRetries,
    required this.initialDelay,
    required this.maxDelay,
    required this.backoffMultiplier,
    required this.escalationChannels,
    required this.escalationDelay,
  });

  factory RetrySettings.defaultSettings() {
    return const RetrySettings(
      maxRetries: 3,
      initialDelay: Duration(minutes: 5),
      maxDelay: Duration(hours: 1),
      backoffMultiplier: 2.0,
      escalationChannels: ['sms', 'call'],
      escalationDelay: Duration(minutes: 15),
    );
  }

  RetrySettings copyWith({
    int? maxRetries,
    Duration? initialDelay,
    Duration? maxDelay,
    double? backoffMultiplier,
    List<String>? escalationChannels,
    Duration? escalationDelay,
  }) {
    return RetrySettings(
      maxRetries: maxRetries ?? this.maxRetries,
      initialDelay: initialDelay ?? this.initialDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
      escalationChannels: escalationChannels ?? this.escalationChannels,
      escalationDelay: escalationDelay ?? this.escalationDelay,
    );
  }
}

class AlertSettings {
  final bool push;
  final bool email;
  final bool sms;
  final bool call;
  final Map<String, Map<String, bool>> severityOverrides;
  final RetrySettings retrySettings;
  // Forwarding mode when caregiver does not respond.
  // Allowed values: 'none', 'attempts', 'elapsed_time'
  final String forwardingMode;
  // Number of failed notification attempts before forwarding when mode=='attempts'
  final int forwardingAttemptThreshold;
  // Seconds to wait before forwarding when mode=='elapsed_time'
  final int forwardingElapsedThresholdSeconds;

  AlertSettings({
    required this.push,
    required this.email,
    required this.sms,
    required this.call,
    required this.severityOverrides,
    required this.retrySettings,
    this.forwardingMode = 'none',
    this.forwardingAttemptThreshold = 3,
    this.forwardingElapsedThresholdSeconds = 60,
  });

  factory AlertSettings.defaultSettings() {
    return AlertSettings(
      push: true,
      email: false,
      sms: false,
      call: false,
      severityOverrides: {
        'critical': {'push': true, 'email': true, 'sms': true, 'call': true},
        'warning': {'push': true, 'email': false, 'sms': false, 'call': false},
      },
      retrySettings: RetrySettings.defaultSettings(),
      forwardingMode: 'none',
      forwardingAttemptThreshold: 3,
      forwardingElapsedThresholdSeconds: 60,
    );
  }

  AlertSettings copyWith({
    bool? push,
    bool? email,
    bool? sms,
    bool? call,
    Map<String, Map<String, bool>>? severityOverrides,
    RetrySettings? retrySettings,
    String? forwardingMode,
    int? forwardingAttemptThreshold,
    int? forwardingElapsedThresholdSeconds,
  }) {
    return AlertSettings(
      push: push ?? this.push,
      email: email ?? this.email,
      sms: sms ?? this.sms,
      call: call ?? this.call,
      severityOverrides: severityOverrides ?? this.severityOverrides,
      retrySettings: retrySettings ?? this.retrySettings,
      forwardingMode: forwardingMode ?? this.forwardingMode,
      forwardingAttemptThreshold:
          forwardingAttemptThreshold ?? this.forwardingAttemptThreshold,
      forwardingElapsedThresholdSeconds:
          forwardingElapsedThresholdSeconds ??
          this.forwardingElapsedThresholdSeconds,
    );
  }

  bool shouldShowPush(String severity) {
    final override = severityOverrides[severity.toLowerCase()];
    if (override != null && override.containsKey('push')) {
      return override['push']!;
    }
    return push;
  }
}

class AlertSettingsManager {
  static AlertSettingsManager? _instance;
  final AlertSettings _settings = AlertSettings.defaultSettings();
  bool _isFetching = false;

  AlertSettingsManager._();

  static AlertSettingsManager get instance {
    _instance ??= AlertSettingsManager._();
    return _instance!;
  }

  AlertSettings get settings => _settings;

  //  uncomment and implement real fetch từ đây
  Future<void> refreshFromServer() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      //
      // final res = await http.get(Uri.parse("https://..../api/v1/feature/alert-settings"),
      //   headers: {
      //     'Authorization': 'Bearer <token>',
      //     'Content-Type': 'application/json',
      //   });
      // if (res.statusCode == 200) {
      //   final body = json.decode(res.body);
      //   // parse into AlertSettings, e.g.:
      //   _settings = AlertSettings(
      //     push: body['push'],
      //     email: body['email'],
      //     sms: body['sms'],
      //     call: body['call'],
      //     severityOverrides: Map<String, Map<String, bool>>.from(
      //       (body['severity_overrides'] as Map).map((k, v) =>
      //           MapEntry(k as String, Map<String, bool>.from(v as Map))),
      //     ),
      //   );
      // }
      //
    } catch (_) {
      // swallow: fallback to default
    } finally {
      _isFetching = false;
    }
  }
}
