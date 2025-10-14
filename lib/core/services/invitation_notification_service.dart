import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:flutter/foundation.dart';

class InvitationNotificationService {
  final ApiClient _api;

  InvitationNotificationService({ApiClient? api})
    : _api = api ?? ApiClient(tokenProvider: AuthStorage.getAccessToken);

  Future<void> sendInvitationEmail({
    required String recipientEmail,
    required String recipientName,
    required String inviterName,
    required String invitationLink,
    required String pin,
  }) async {
    final body = {
      'to': recipientEmail,
      'recipient_name': recipientName,
      'inviter_name': inviterName,
      'invitation_link': invitationLink,
      'pin': pin,
      'type': 'caregiver_invitation',
    };

    final res = await _api.post('/notifications/email', body: body);
    if (res.statusCode != 200) {
      throw Exception('Send email failed: ${res.statusCode} ${res.body}');
    }

    debugPrint(
      '[InvitationNotificationService] Invitation email sent to $recipientEmail',
    );
  }

  Future<void> sendInvitationSMS({
    required String recipientPhone,
    required String recipientName,
    required String inviterName,
    required String pin,
  }) async {
    final body = {
      'to': recipientPhone,
      'recipient_name': recipientName,
      'inviter_name': inviterName,
      'pin': pin,
      'type': 'caregiver_invitation',
    };

    final res = await _api.post('/notifications/sms', body: body);
    if (res.statusCode != 200) {
      throw Exception('Send SMS failed: ${res.statusCode} ${res.body}');
    }

    debugPrint(
      '[InvitationNotificationService] Invitation SMS sent to $recipientPhone',
    );
  }

  Future<void> sendInvitation({
    required String recipientEmail,
    required String recipientPhone,
    required String recipientName,
    required String inviterName,
    required String invitationLink,
    required String pin,
    required bool sendEmail,
    required bool sendSMS,
  }) async {
    final futures = <Future>[];

    if (sendEmail && recipientEmail.isNotEmpty) {
      futures.add(
        sendInvitationEmail(
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          inviterName: inviterName,
          invitationLink: invitationLink,
          pin: pin,
        ),
      );
    }

    if (sendSMS && recipientPhone.isNotEmpty) {
      futures.add(
        sendInvitationSMS(
          recipientPhone: recipientPhone,
          recipientName: recipientName,
          inviterName: inviterName,
          pin: pin,
        ),
      );
    }

    if (futures.isEmpty) {
      throw Exception('No valid contact method provided');
    }

    await Future.wait(futures);
    debugPrint('[InvitationNotificationService] Invitation sent successfully');
  }
}
