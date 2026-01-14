import 'dart:async';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/data/shared_permissions_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/models/shared_permissions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton service để quản lý permissions và broadcast changes
class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();
  factory PermissionsService() => _instance;
  PermissionsService._internal();

  final _repo = SharedPermissionsRemoteDataSource();
  final _permissionsController =
      StreamController<List<SharedPermissions>>.broadcast();

  List<SharedPermissions> _cachedPermissions = [];
  dynamic _permSub;
  dynamic _inviteSub;
  String? _currentCaregiverId;

  /// Stream để listen permission changes
  Stream<List<SharedPermissions>> get permissionsStream =>
      _permissionsController.stream;

  /// Get current permissions (cached)
  List<SharedPermissions> get currentPermissions => _cachedPermissions;

  /// Initialize service và setup realtime subscriptions
  Future<void> initialize() async {
    try {
      _currentCaregiverId = await AuthStorage.getUserId();
      if (_currentCaregiverId == null) {
        AppLogger.w('[PermissionsService] Cannot initialize: userId is null');
        return;
      }

      AppLogger.i(
        '[PermissionsService] Initializing for caregiverId=$_currentCaregiverId',
      );

      await _loadPermissions();
      await _setupRealtimeSubscriptions();
    } catch (e) {
      AppLogger.e(
        '[PermissionsService] Initialize failed: $e',
        e,
        StackTrace.current,
      );
    }
  }

  /// Load permissions và broadcast
  Future<void> _loadPermissions() async {
    try {
      if (_currentCaregiverId == null) return;

      AppLogger.i(
        '[PermissionsService] 📡 Loading permissions from API for caregiverId=$_currentCaregiverId',
      );
      final perms = await _repo.getByCaregiverId(_currentCaregiverId!);

      AppLogger.i(
        '[PermissionsService] ✅ Loaded ${perms.length} permissions from API',
      );

      // Log detailed permissions
      for (final p in perms) {
        AppLogger.d(
          '[PermissionsService]   → customerId=${p.customerId}, profileView=${p.profileView}, alertAck=${p.alertAck}',
        );
      }

      _cachedPermissions = perms;
      _permissionsController.add(perms);

      AppLogger.i(
        '[PermissionsService] 📤 Broadcasted ${perms.length} permissions to listeners',
      );
    } catch (e) {
      AppLogger.e(
        '[PermissionsService] Load failed: $e',
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

      // Subscribe to permissions table - FILTER by current caregiver
      try {
        _permSub = client
            .from('permissions')
            .stream(primaryKey: ['id'])
            .eq('caregiver_id', _currentCaregiverId!)
            .listen(
              (data) {
                AppLogger.i(
                  '[PermissionsService] 🔔 Permissions stream update: ${data.length} rows for caregiverId=$_currentCaregiverId',
                );
                AppLogger.d('[PermissionsService] Stream data: $data');
                _loadPermissions(); // Reload và broadcast
              },
              onError: (e) =>
                  AppLogger.w('[PermissionsService] Stream error: $e'),
            );
        AppLogger.i(
          '[PermissionsService] ✅ Permissions stream subscribed with filter: caregiver_id=$_currentCaregiverId',
        );
      } catch (e) {
        AppLogger.w('[PermissionsService] Permissions subscription failed: $e');
      }

      // Subscribe to invitations table - FILTER by current caregiver
      try {
        _inviteSub = client
            .from('caregiver_invitations')
            .stream(primaryKey: ['id'])
            .eq('caregiver_id', _currentCaregiverId!)
            .listen(
              (data) {
                AppLogger.i(
                  '[PermissionsService] 🔔 Invitations stream update: ${data.length} rows for caregiverId=$_currentCaregiverId',
                );
                _loadPermissions(); // Reload và broadcast
              },
              onError: (e) => AppLogger.w(
                '[PermissionsService] Invitations stream error: $e',
              ),
            );
        AppLogger.i(
          '[PermissionsService] ✅ Invitations stream subscribed with filter: caregiver_id=$_currentCaregiverId',
        );
      } catch (e) {
        AppLogger.w('[PermissionsService] Invitations subscription failed: $e');
      }
    } catch (e) {
      AppLogger.e(
        '[PermissionsService] Realtime setup failed: $e',
        e,
        StackTrace.current,
      );
    }
  }

  /// Check if has any permissions (user still has access)
  bool hasAnyPermissions() {
    return _cachedPermissions.isNotEmpty;
  }

  /// Get permissions for specific customer
  SharedPermissions? getPermissionsForCustomer(String customerId) {
    try {
      return _cachedPermissions.firstWhere((p) => p.customerId == customerId);
    } catch (_) {
      return null;
    }
  }

  /// Check specific permission for customer
  bool hasPermission(String customerId, String permissionType) {
    final perm = getPermissionsForCustomer(customerId);

    AppLogger.d(
      '[PermissionsService] hasPermission check: customerId=$customerId, type=$permissionType, found=${perm != null}',
    );

    if (perm == null) {
      AppLogger.w(
        '[PermissionsService] ⚠️ No permission found for customerId=$customerId',
      );
      AppLogger.d(
        '[PermissionsService] Available customers: ${_cachedPermissions.map((p) => p.customerId).toList()}',
      );
      return false;
    }

    AppLogger.d(
      '[PermissionsService] Permission details: profileView=${perm.profileView}, alertAck=${perm.alertAck}, streamView=${perm.streamView}',
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

  /// Get report access days limit for customer
  int getReportAccessDays(String customerId) {
    final perm = getPermissionsForCustomer(customerId);
    return perm?.reportAccessDays ?? 0;
  }

  /// Get log access days limit for customer
  int getLogAccessDays(String customerId) {
    final perm = getPermissionsForCustomer(customerId);
    return perm?.logAccessDays ?? 0;
  }

  /// Dispose service
  void dispose() {
    _permSub?.cancel();
    _inviteSub?.cancel();
    _permissionsController.close();
  }
}
