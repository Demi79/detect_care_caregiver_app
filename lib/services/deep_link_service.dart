import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final StreamController<Uri> _linkController =
      StreamController<Uri>.broadcast();

  Stream<Uri> get uriLinkStream => _linkController.stream;

  Future<void> init() async {
    _appLinks ??= AppLinks();

    // Handle initial link
    try {
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial link: $e');
    }

    // Handle incoming links
    _linkSubscription = _appLinks!.uriLinkStream.listen(
      (uri) {
        _handleUri(uri);
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  void _handleUri(Uri uri) {
    debugPrint('Received deep link: $uri');
    _linkController.add(uri);
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkController.close();
  }
}

class PaymentStorageService {
  static const String _pendingPaymentsKey = 'pending_payments';

  static Future<void> savePendingPayment({
    required String transactionId,
    required String planCode,
    required double amount,
    required DateTime createdAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingPayments = await getPendingPayments();

    pendingPayments[transactionId] = {
      'planCode': planCode,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'status': 'pending',
    };

    await prefs.setString(_pendingPaymentsKey, jsonEncode(pendingPayments));
  }

  static Future<Map<String, dynamic>> getPendingPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_pendingPaymentsKey);
    if (data != null) {
      return Map<String, dynamic>.from(jsonDecode(data));
    }
    return {};
  }

  static Future<void> updatePaymentStatus(
    String transactionId,
    String status,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingPayments = await getPendingPayments();

    if (pendingPayments.containsKey(transactionId)) {
      pendingPayments[transactionId]['status'] = status;
      await prefs.setString(_pendingPaymentsKey, jsonEncode(pendingPayments));
    }
  }

  static Future<void> removePendingPayment(String transactionId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingPayments = await getPendingPayments();
    pendingPayments.remove(transactionId);
    await prefs.setString(_pendingPaymentsKey, jsonEncode(pendingPayments));
  }

  static Future<Map<String, dynamic>?> getPendingPayment(
    String transactionId,
  ) async {
    final pendingPayments = await getPendingPayments();
    return pendingPayments[transactionId];
  }
}
