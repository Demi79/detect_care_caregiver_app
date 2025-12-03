import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:detect_care_caregiver_app/core/services/direct_caller.dart';

String normalizePhoneNumber(String phone) {
  var normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  if (normalized.startsWith('+84')) {
    normalized = '0${normalized.substring(3)}';
  } else if (normalized.startsWith('84')) {
    normalized = '0${normalized.substring(2)}';
  }
  return normalized;
}

Future<void> fallbackDial(BuildContext context, String normalized) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await launchUrl(Uri.parse('tel:$normalized'));
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Không thể thực hiện cuộc gọi'),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> attemptCall({
  required BuildContext context,
  required String rawPhone,
  required String actionLabel,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final normalized = normalizePhoneNumber(rawPhone);

  try {
    final status = await Permission.phone.request();
    if (status.isGranted) {
      final success = await DirectCaller.call(normalized);
      if (success) {
        messenger.showSnackBar(
          SnackBar(content: Text('$actionLabel: Đang gọi $normalized...')),
        );
        return;
      }
      await fallbackDial(context, normalized);
      return;
    }
    if (status.isPermanentlyDenied) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Quyền gọi điện bị từ chối vĩnh viễn. Vui lòng bật quyền trong cài đặt.',
          ),
          action: SnackBarAction(
            label: 'Cài đặt',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      await fallbackDial(context, normalized);
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Quyền gọi điện bị từ chối.'),
        backgroundColor: Colors.orange,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Lỗi khi gọi: $e'),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
