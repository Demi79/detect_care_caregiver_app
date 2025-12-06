import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_context.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_service.dart';
import 'package:detect_care_caregiver_app/features/emergency_contacts/data/emergency_contacts_remote_data_source.dart';

class EmergencyCallHelper {
  static Future<void> initiateEmergencyCall(BuildContext context) async {
    bool canEmergency = true;
    try {
      final manager = callActionManager(context);
      canEmergency = manager.allowedActions.contains(CallAction.emergency);
    } catch (e) {
      canEmergency = true;
    }
    if (!canEmergency) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn đã có người chăm sóc. Trong trường hợp khẩn cấp hệ thống sẽ liên hệ người chăm sóc trước.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    List<EmergencyContactDto> contacts = [];
    try {
      final ds = EmergencyContactsRemoteDataSource();
      final customerId = await ds.resolveCustomerId();
      if (customerId != null && customerId.isNotEmpty) {
        contacts = await ds.list(customerId);
      }
    } catch (e) {
      try {
        print('[EmergencyCallHelper] failed to load emergency contacts: $e');
      } catch (_) {}
    }

    final valid = contacts.where((c) => c.phone.trim().isNotEmpty).toList();
    valid.sort((a, b) => (a.alertLevel ?? 99).compareTo(b.alertLevel ?? 99));

    if (valid.isEmpty) {
      await attemptCall(
        context: context,
        rawPhone: '115',
        actionLabel: 'Gọi khẩn cấp',
      );
      return;
    }

    final options = <Map<String, String>>[];
    for (final c in valid) {
      final lvl = (c.alertLevel == null) ? '' : 'CẤP ${c.alertLevel}';
      final label = (c.name.trim().isNotEmpty == true)
          ? '$lvl: ${c.name} — ${c.phone}'
          : '$lvl: ${c.phone}';
      options.add({'label': label, 'phone': c.phone.trim()});
      if (options.length >= 2) break;
    }
    options.add({'label': 'Gọi số khẩn cấp (112)', 'phone': '112'});

    String? chosen;
    try {
      chosen = await showModalBottomSheet<String?>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Chọn số để gọi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                ...options.map(
                  (o) => ListTile(
                    title: Text(o['label'] ?? ''),
                    onTap: () => Navigator.of(ctx).pop(o['phone']),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    } catch (e) {
      try {
        print('[EmergencyCallHelper] showModalBottomSheet error: $e');
      } catch (_) {}
      chosen = null;
    }
    if (chosen == null) return;

    try {
      print('[EmergencyCallHelper] chosen phone: $chosen');
    } catch (_) {}

    await attemptCall(
      context: context,
      rawPhone: chosen,
      actionLabel: 'Gọi khẩn cấp',
    );
  }
}
