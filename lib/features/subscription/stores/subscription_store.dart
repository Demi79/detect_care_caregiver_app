import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

import '../data/service_package_api.dart';

class SubscriptionStore extends ChangeNotifier {
  SubscriptionStore._privateConstructor() {
    _api = ServicePackageApi();
  }

  static final SubscriptionStore instance =
      SubscriptionStore._privateConstructor();

  late ServicePackageApi _api;

  Map<String, dynamic>? _planData;
  Map<String, dynamic>? get planData => _planData;

  /// Returns whether we currently have cached plan/subscription data.
  bool get hasData => _planData != null;

  /// Refresh the cached plan/subscription data by calling the API. This will
  /// notify listeners when new data is available.
  Future<void> refresh() async {
    try {
      AppLogger.api('[SubscriptionStore] refresh called');
      final data = await _api.getCurrentSubscription();
      _planData = data;
      AppLogger.api(
        '[SubscriptionStore] refresh result keys: ${data?.keys.toList()}',
      );
      notifyListeners();
    } catch (e) {
      AppLogger.apiError('[SubscriptionStore] refresh error: $e');
      // Swallow errors - callers can still request explicit API calls.
      if (kDebugMode) {
        // ignore: avoid_print
        print('[SubscriptionStore] refresh error: $e');
      }
    }
  }

  /// Replace the underlying API client instance. This is intended for tests
  /// so callers can inject a fake `ServicePackageApi` implementation.
  @visibleForTesting
  void setApi(ServicePackageApi api) {
    _api = api;
  }

  /// Clear cached data (useful for sign-out flows)
  void clear() {
    _planData = null;
    notifyListeners();
  }
}
