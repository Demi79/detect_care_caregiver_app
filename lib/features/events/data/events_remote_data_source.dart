import 'dart:developer' as dev;
import 'dart:convert' as convert;
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
// import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';

class EventsRemoteDataSource {
  final ApiClient _api;
  EventsRemoteDataSource({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<void> updateEvent({
    required String eventId,
    required String status,
    required String notes,
  }) async {
    final body = {'status': status, 'notes': notes};
    dev.log('\n📤 [Events] Update event payload: ${body.toString()}');

    final res = await _api.patch('/events/$eventId', body: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      String serverMsg = res.body;
      try {
        final decoded = convert.jsonDecode(res.body);
        if (decoded is Map) {
          if (decoded.containsKey('error') &&
              decoded['error'] is Map &&
              decoded['error']['message'] != null) {
            serverMsg = decoded['error']['message'].toString();
          } else if (decoded['message'] != null) {
            serverMsg = decoded['message'].toString();
          } else {
            serverMsg = convert.jsonEncode(decoded);
          }
        }
      } catch (_) {}

      throw Exception('Update event failed: ${res.statusCode} $serverMsg');
    }
  }

  Future<List<Map<String, dynamic>>> listEvents() async {
    dev.log('\n📥 [Events] Listing events via REST /events (no query params)');
    final res = await _api.get('/events');
    dev.log('Status: ${res.statusCode}');
    dev.log('Body: ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('List events failed: ${res.statusCode} ${res.body}');
    }

    final data = _api.extractDataFromResponse(res);
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    if (data is Map && data.containsKey('data') && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    }
    throw Exception('Unexpected events list response shape');
  }

  Future<void> confirmEvent({
    required String eventId,
    bool? confirm,
    String? confirmStatus,
    bool? confirmStatusBool,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (confirm != null) body['confirm'] = confirm;
    if (confirmStatus != null) body['confirm_status'] = confirmStatus;
    if (confirmStatusBool != null) body['confirm_status'] = confirmStatusBool;
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

    final res = await _api.patch(
      '/event-detections/$eventId/confirm-status',
      body: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      String serverMsg = res.body;
      try {
        final decoded = convert.jsonDecode(res.body);
        if (decoded is Map) {
          if (decoded.containsKey('error') &&
              decoded['error'] is Map &&
              decoded['error']['message'] != null) {
            serverMsg = decoded['error']['message'].toString();
          } else if (decoded['message'] != null) {
            serverMsg = decoded['message'].toString();
          } else {
            serverMsg = convert.jsonEncode(decoded);
          }
        }
      } catch (_) {}

      throw Exception('Confirm event failed: ${res.statusCode} $serverMsg');
    }
  }
}
