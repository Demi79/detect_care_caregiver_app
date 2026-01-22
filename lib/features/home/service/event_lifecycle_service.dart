import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class EventLifecycleService {
  final ApiClient _api;

  EventLifecycleService.withDefaultClient()
    : _api = ApiClient(tokenProvider: AuthStorage.getAccessToken);

  EventLifecycleService(this._api);

  Future<void> updateLifecycleFlags({
    required String eventId,
    bool? hasEmergencyCall,
    bool? hasAlarmActivated,
  }) async {
    final body = <String, dynamic>{};
    if (hasEmergencyCall != null) body['has_emergency_call'] = hasEmergencyCall;
    if (hasAlarmActivated != null)
      body['has_alarm_activated'] = hasAlarmActivated;

    AppLogger.api('PATCH /events/$eventId/lifecycle-flags body=$body');

    try {
      final res = await _api.patch(
        '/events/$eventId/lifecycle-flags',
        body: body,
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        AppLogger.apiError(
          'Update lifecycle flags failed: ${res.statusCode} ${res.body}',
        );
        throw Exception(
          'Update lifecycle flags failed: ${res.statusCode} ${res.body}',
        );
      }

      AppLogger.api('Update lifecycle flags success: ${res.statusCode}');
    } catch (e, st) {
      AppLogger.e('Update lifecycle flags error for $eventId: $e', e, st);
      rethrow;
    }
  }
}
