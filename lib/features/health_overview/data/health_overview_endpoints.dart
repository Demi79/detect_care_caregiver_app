import 'package:detect_care_caregiver_app/core/config/app_config.dart';

class HealthOverviewEndpoints {
  final String base;
  HealthOverviewEndpoints([String? overrideBase])
    : base = overrideBase ?? AppConfig.apiBaseUrl;

  Uri getHealthOverview({
    String? patientId,
    String? startDate,
    String? endDate,
  }) {
    final params = <String, String>{};
    if (patientId != null) params['userId'] = patientId;
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;

    return Uri.parse(
      '$base/health/reports/overview',
    ).replace(queryParameters: params.isEmpty ? null : params);
  }
}
