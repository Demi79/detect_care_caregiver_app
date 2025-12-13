import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/data/shared_permissions_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/models/shared_permissions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider để quản lý permissions và notify tất cả listeners
class PermissionsProvider extends ChangeNotifier {
  final _repo = SharedPermissionsRemoteDataSource();

  List<SharedPermissions> _permissions = [];
  dynamic _permSub;
  dynamic _inviteSub;
  String? _currentCaregiverId;
  bool _isInitialized = false;

  List<SharedPermissions> get permissions => _permissions;
  bool get isInitialized => _isInitialized;

  /// Initialize provider và setup realtime subscriptions
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.d('[PermissionsProvider] Already initialized, skipping');
      return;
    }

    try {
      _currentCaregiverId = await AuthStorage.getUserId();
      if (_currentCaregiverId == null) {
        AppLogger.w('[PermissionsProvider] Cannot initialize: userId is null');
        return;
      }

      AppLogger.i(
        '[PermissionsProvider] 🚀 Initializing for caregiverId=$_currentCaregiverId',
      );

      await _loadPermissions();
      await _setupRealtimeSubscriptions();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      AppLogger.e(
        '[PermissionsProvider] Initialize failed: $e',
        e,
        StackTrace.current,
      );
    }
  }

  /// Load permissions from API
  Future<void> _loadPermissions() async {
    try {
      if (_currentCaregiverId == null) return;

      AppLogger.i(
        '[PermissionsProvider] 📡 Loading permissions from API for caregiverId=$_currentCaregiverId',
      );
      final perms = await _repo.getByCaregiverId(_currentCaregiverId!);

      AppLogger.i(
        '[PermissionsProvider] ✅ Loaded ${perms.length} permissions from API',
      );

      // Log detailed permissions
      for (final p in perms) {
        AppLogger.d(
          '[PermissionsProvider]   → customerId=${p.customerId}, profileView=${p.profileView}, alertAck=${p.alertAck}, reportAccessDays=${p.reportAccessDays}',
        );
      }

      _permissions = perms;
      notifyListeners();

      AppLogger.i('[PermissionsProvider] 📤 Notified all listeners');
    } catch (e) {
      AppLogger.e(
        '[PermissionsProvider] Load failed: $e',
        e,
        StackTrace.current,
      );
    }
  }

  /// Setup Supabase realtime subscriptions
  Future<void> _setupRealtimeSubscriptions() async {
    if (_currentCaregiverId == null) return;

    try {
      final client = Supabase.instance.client;

      // Subscribe to permissions table
      try {
        _permSub = client
            .from('permissions')
            .stream(primaryKey: ['id'])
            .eq('caregiver_id', _currentCaregiverId!)
            .listen(
              (data) {
                AppLogger.i(
                  '[PermissionsProvider] 🔔 Permissions stream update: ${data.length} rows',
                );
                AppLogger.d('[PermissionsProvider] Stream data: $data');
                _loadPermissions();
              },
              onError: (e) =>
                  AppLogger.w('[PermissionsProvider] Stream error: $e'),
            );
        AppLogger.i('[PermissionsProvider] ✅ Permissions stream subscribed');
      } catch (e) {
        AppLogger.w(
          '[PermissionsProvider] Permissions subscription failed: $e',
        );
      }

      // Subscribe to caregiver_invitations table
      try {
        _inviteSub = client
            .from('caregiver_invitations')
            .stream(primaryKey: ['id'])
            .eq('caregiver_id', _currentCaregiverId!)
            .listen(
              (data) {
                AppLogger.i(
                  '[PermissionsProvider] 🔔 Invitations stream update: ${data.length} rows',
                );
                _loadPermissions();
              },
              onError: (e) => AppLogger.w(
                '[PermissionsProvider] Invitations stream error: $e',
              ),
            );
        AppLogger.i('[PermissionsProvider] ✅ Invitations stream subscribed');
      } catch (e) {
        AppLogger.w(
          '[PermissionsProvider] Invitations subscription failed: $e',
        );
      }
    } catch (e) {
      AppLogger.e(
        '[PermissionsProvider] Realtime setup failed: $e',
        e,
        StackTrace.current,
      );
    }
  }

  /// Check specific permission for customer
  bool hasPermission(String customerId, String permissionType) {
    final perm = _permissions.firstWhereOrNull(
      (p) => p.customerId == customerId,
    );

    AppLogger.d(
      '[PermissionsProvider] hasPermission: customerId=$customerId, type=$permissionType, found=${perm != null}',
    );

    if (perm == null) {
      AppLogger.w(
        '[PermissionsProvider] ⚠️ No permission for customerId=$customerId. Available: ${_permissions.map((p) => p.customerId).toList()}',
      );
      return false;
    }

    AppLogger.d(
      '[PermissionsProvider] Permission: profileView=${perm.profileView}, alertAck=${perm.alertAck}',
    );

    switch (permissionType) {
      case 'stream_view':
        return perm.streamView == true;
      case 'alert_read':
        return perm.alertRead == true;
      case 'alert_ack':
        return perm.alertAck == true;
      case 'profile_view':
        return perm.profileView == true;
      default:
        return false;
    }
  }

  /// Get report access days limit
  int getReportAccessDays(String customerId) {
    final perm = _permissions.firstWhereOrNull(
      (p) => p.customerId == customerId,
    );
    return perm?.reportAccessDays ?? 0;
  }

  /// Get log access days limit
  int getLogAccessDays(String customerId) {
    final perm = _permissions.firstWhereOrNull(
      (p) => p.customerId == customerId,
    );
    return perm?.logAccessDays ?? 0;
  }

  @override
  void dispose() {
    _permSub?.cancel();
    _inviteSub?.cancel();
    super.dispose();
  }
}

// Extension để tìm element có điều kiện (giống firstWhere nhưng có orElse)
extension FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (_) {
      return null;
    }
  }
}
