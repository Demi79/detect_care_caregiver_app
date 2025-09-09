import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';

class EventsRemoteDataSource {
  final ApiClient _api;
  EventsRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<void> updateEvent({
    required String eventId,
    required String status,
    required String notes,
  }) async {
    final res = await _api.patch(
      '/events/$eventId',
      query: {'status': status, 'notes': notes},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update event failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> confirmEvent({
    required String eventId,
    bool? confirm,
    String? confirmStatus, // legacy (normal|warning|danger)
    String? notes,
  }) async {
    final query = <String, dynamic>{};

    if (confirm != null) {
      query['confirm'] = confirm.toString();
    }
    if (confirmStatus != null) {
      query['confirm_status'] = confirmStatus;
    }
    if (notes != null && notes.isNotEmpty) {
      query['notes'] = notes;
    }

    print('\n📤 [Events] Confirming event:');
    print('URL: /events/$eventId/confirm');
    print('Query params:');
    print('  confirm: ${query['confirm']}');
    print('  confirm_status: ${query['confirm_status']}');
    print('  notes: ${query['notes']}');

    final res = await _api.patch('/events/$eventId/confirm', query: query);

    print('\n📥 [Events] Confirm response:');
    print('Status: ${res.statusCode}');
    print('Body: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Confirm event failed: ${res.statusCode} ${res.body}');
    }
  }
}
