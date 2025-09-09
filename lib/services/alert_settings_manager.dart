class AlertSettings {
  final bool push;
  final bool email;
  final bool sms;
  final bool call;
  final Map<String, Map<String, bool>> severityOverrides;

  AlertSettings({
    required this.push,
    required this.email,
    required this.sms,
    required this.call,
    required this.severityOverrides,
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
    );
  }

  AlertSettings copyWith({
    bool? push,
    bool? email,
    bool? sms,
    bool? call,
    Map<String, Map<String, bool>>? severityOverrides,
  }) {
    return AlertSettings(
      push: push ?? this.push,
      email: email ?? this.email,
      sms: sms ?? this.sms,
      call: call ?? this.call,
      severityOverrides: severityOverrides ?? this.severityOverrides,
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
