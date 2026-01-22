import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:detect_care_caregiver_app/core/services/direct_caller.dart';
import 'package:detect_care_caregiver_app/core/utils/phone_utils.dart';

String normalizePhoneNumber(String phone) {
  // Prefer central phone utilities to produce a local format starting with 0
  try {
    final local = PhoneUtils.toLocalVietnamese(phone);
    // Ensure only digits and starts with 0
    final cleaned = local.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) return cleaned;
    // If PhoneUtils returned something unexpected, fall back to manual cleanup
  } catch (_) {}

  // Fallback manual normalization (robust against +84, 0084, 84 prefixes)
  var normalized = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  if (normalized.startsWith('00')) normalized = normalized.substring(2);
  if (normalized.startsWith('84')) normalized = '0${normalized.substring(2)}';
  if (!normalized.startsWith('0')) normalized = '0$normalized';
  // Strip any non-digit characters just in case
  normalized = normalized.replaceAll(RegExp(r'\D'), '');
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
    try {
      print('[attemptCall] rawPhone=$rawPhone normalized=$normalized');
    } catch (_) {}
    final status = await Permission.phone.request();
    try {
      print('[attemptCall] permission status: $status');
    } catch (_) {}
    if (status.isGranted) {
      try {
        print('[attemptCall] invoking DirectCaller.call($normalized)');
      } catch (_) {}
      final success = await DirectCaller.call(normalized);
      try {
        print('[attemptCall] DirectCaller returned: $success');
      } catch (_) {}
      if (success) {
        messenger.showSnackBar(
          SnackBar(content: Text('$actionLabel: Đang gọi $normalized...')),
        );
        return;
      }
      try {
        print('[attemptCall] DirectCaller failed, falling back to dialer');
      } catch (_) {}
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

    try {
      print('[attemptCall] permission denied, falling back to dialer');
    } catch (_) {}
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Quyền gọi điện bị từ chối. Mở app quay số.'),
        backgroundColor: Colors.orange,
      ),
    );
    await fallbackDial(context, normalized);
  } catch (e) {
    try {
      print('[attemptCall] caught error: $e');
    } catch (_) {}
    messenger.showSnackBar(
      SnackBar(
        content: Text('Lỗi khi gọi: $e'),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
