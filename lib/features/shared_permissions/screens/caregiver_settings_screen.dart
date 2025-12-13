import 'dart:async';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/data/shared_permissions_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/models/shared_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CaregiverSettingsScreen extends StatefulWidget {
  final bool embedInParent;

  const CaregiverSettingsScreen({super.key, this.embedInParent = false});

  @override
  State<CaregiverSettingsScreen> createState() =>
      _CaregiverSettingsScreenState();
}

class _CaregiverSettingsScreenState extends State<CaregiverSettingsScreen> {
  final _repo = SharedPermissionsRemoteDataSource();
  List<SharedPermissions> _permissions = [];
  bool _loading = true;
  dynamic _permSub;
  dynamic _inviteSub;
  Timer? _debounceReloadTimer;

  static const primaryBlue = Color(0xFF007AFF);
  static const bgColor = Color(0xFFF8FAFC);
  static const cardColor = Colors.white;

  /// Validates days input for permission requests
  String? _validateDaysInput(String value, int maxValue) {
    if (value.isEmpty) return null;
    final days = int.tryParse(value);
    if (days == null) {
      return 'Chỉ được nhập số';
    }
    if (days <= 0) {
      return 'Số ngày phải lớn hơn 0';
    }
    if (days > maxValue) {
      return 'Tối đa $maxValue ngày';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    AppLogger.i('[CaregiverSettings] ✅ Screen initialized');
    _loadPermissions();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _debounceReloadTimer?.cancel();
    try {
      _permSub?.unsubscribe?.call();
    } catch (_) {}
    try {
      _inviteSub?.unsubscribe?.call();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    try {
      final caregiverId = await AuthStorage.getUserId();
      if (caregiverId == null) throw Exception('Missing caregiver_id');
      AppLogger.d(
        '[CaregiverSettings] Loading permissions for caregiverId=$caregiverId',
      );
      final perms = await _repo.getByCaregiverId(caregiverId);
      AppLogger.d('[CaregiverSettings] Loaded ${perms.length} permissions');
      setState(() {
        _permissions = perms;
        _loading = false;
      });
    } catch (e) {
      AppLogger.e(
        '[CaregiverSettings] Load permissions error: $e',
        e,
        StackTrace.current,
      );
      setState(() => _loading = false);
    }
  }

  Future<String?> _getLinkedCustomerId(String caregiverId) async {
    final assignmentsDs = AssignmentsRemoteDataSource();
    final assignments = await assignmentsDs.listPending(status: 'accepted');
    final active = assignments
        .where((a) => a.isActive && (a.status.toLowerCase() == 'accepted'))
        .toList();
    return active.isNotEmpty ? active.first.customerId : null;
  }

  Future<void> _setupRealtimeSubscriptions() async {
    try {
      final caregiverId = await AuthStorage.getUserId();
      if (caregiverId == null) {
        AppLogger.w(
          '[CaregiverSettings] Cannot setup realtime: caregiverId is null',
        );
        return;
      }

      AppLogger.d(
        '[CaregiverSettings] Setting up realtime subscriptions for caregiverId=$caregiverId',
      );

      final client = Supabase.instance.client;

      try {
        AppLogger.d('[CaregiverSettings] Subscribing to permissions table');
        _permSub = client
            .from('permissions')
            .stream(primaryKey: ['id'])
            .listen(
              (data) {
                AppLogger.d(
                  '[CaregiverSettings] Permissions stream update: ${data.length} rows',
                );
                _onRealtimePayload(data, caregiverId);
              },
              onError: (e) {
                AppLogger.w('[CaregiverSettings] Permission stream error: $e');
              },
            );
        AppLogger.d('[CaregiverSettings] ✅ Permissions subscription active');
      } catch (e) {
        AppLogger.w('[CaregiverSettings] Permission subscription failed: $e');
      }

      try {
        AppLogger.d(
          '[CaregiverSettings] Subscribing to caregiver_invitations table',
        );
        _inviteSub = client
            .from('caregiver_invitations')
            .stream(primaryKey: ['id'])
            .listen(
              (data) {
                AppLogger.d(
                  '[CaregiverSettings] Invitations stream update: ${data.length} rows',
                );
                _onRealtimePayload(data, caregiverId);
              },
              onError: (e) {
                AppLogger.w('[CaregiverSettings] Invitations stream error: $e');
              },
            );
        AppLogger.d('[CaregiverSettings] ✅ Invitations subscription active');
      } catch (e) {
        AppLogger.w('[CaregiverSettings] Invitations subscription failed: $e');
      }
    } catch (e) {
      AppLogger.e(
        '[CaregiverSettings] Realtime subscription setup failed: $e',
        e,
        StackTrace.current,
      );
    }
  }

  void _onRealtimePayload(dynamic payload, String caregiverId) {
    try {
      AppLogger.d(
        '[CaregiverSettings] Realtime payload received: ${payload.runtimeType}',
      );

      // payload từ stream() là List<Map<String, dynamic>>
      // payload từ .on() cũ là RealtimeMessage với .newRecord
      if (payload is List) {
        // stream() API - chỉ reload là đủ
        AppLogger.i(
          '[CaregiverSettings] 🔄 Reloading permissions due to stream update',
        );
        _scheduleReload();
        return;
      }

      // Fallback cho cách cũ (nếu vẫn còn dùng)
      dynamic data;
      if (payload is Map) {
        data =
            payload['new'] ??
            payload['new_record'] ??
            payload['newRecord'] ??
            payload['old'] ??
            payload['old_record'] ??
            payload['record'] ??
            payload['payload'];
      } else {
        try {
          data = payload.newRecord ?? payload.record;
        } catch (_) {
          data = null;
        }
      }

      final eventCaregiverId = (data is Map)
          ? (data['caregiver_id']?.toString() ??
                data['caregiverId']?.toString())
          : null;

      AppLogger.d(
        '[CaregiverSettings] Realtime event - eventCaregiverId=$eventCaregiverId, currentCaregiverId=$caregiverId',
      );

      if (eventCaregiverId == null || eventCaregiverId == caregiverId) {
        AppLogger.i(
          '[CaregiverSettings] 🔄 Reloading permissions due to realtime event',
        );
        _scheduleReload();
      }
    } catch (e) {
      AppLogger.e(
        '[CaregiverSettings] Realtime payload processing error: $e',
        e,
        StackTrace.current,
      );
    }
  }

  void _scheduleReload() {
    _debounceReloadTimer?.cancel();
    AppLogger.d('[CaregiverSettings] Scheduling reload in 600ms');
    _debounceReloadTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        AppLogger.i('[CaregiverSettings] 📥 Executing debounced reload');
        _loadPermissions();
      }
    });
  }

  // Popup nhập lý do + số ngày
  Future<void> _showRequestDialog({
    required String type,
    required String displayName,
    bool isDaysType = false,
    int maxValue = 0,
  }) async {
    final TextEditingController reasonController = TextEditingController();
    final TextEditingController daysController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.only(top: 8, right: 8, left: 12),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, color: primaryBlue),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Đóng',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Yêu cầu quyền: $displayName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isDaysType)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Tối đa được $maxValue ngày',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (isDaysType)
                TextField(
                  controller: daysController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Số ngày muốn yêu cầu',
                    hintText: 'Nhập chỉ số (không chữ cái)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    errorText: _validateDaysInput(
                      daysController.text,
                      maxValue,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                textAlign: TextAlign.center,
                maxLines: 2,
                maxLength: 200,
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                decoration: InputDecoration(
                  labelText: 'Lý do yêu cầu',
                  hintText: 'Nhập lý do (tối đa 200 ký tự)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  counterText: '',
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Gửi yêu cầu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Vui lòng nhập lý do!'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                if (isDaysType) {
                  final days = int.tryParse(daysController.text);
                  if (days == null || days <= 0 || days > maxValue) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Số ngày không hợp lệ!'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _submitDaysRequest(type, days, reason);
                } else {
                  Navigator.pop(context);
                  _submitPermissionRequest(type, reason);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitPermissionRequest(String type, String reason) async {
    try {
      final caregiverId = await AuthStorage.getUserId();
      if (caregiverId == null) throw Exception('Missing caregiverId');
      final customerId = await _getLinkedCustomerId(caregiverId);
      if (customerId == null || customerId.isEmpty) {
        AppLogger.w('[CaregiverSettings] Linked customer not found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy khách hàng được liên kết.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      AppLogger.i(
        '[CaregiverSettings] Requesting permission: type=$type, reason=$reason',
      );
      final res = await _repo.createPermissionRequest(
        customerId: customerId,
        caregiverId: caregiverId,
        type: type,
        requestedBool: true,
        scope: 'read',
        reason: reason,
      );

      AppLogger.d('[CaregiverSettings] ✅ Permission request response: $res');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã gửi yêu cầu quyền $type'),
          backgroundColor: Colors.green,
        ),
      );
      _loadPermissions();
    } catch (e) {
      AppLogger.e(
        '[CaregiverSettings] Request permission failed: $e',
        e,
        StackTrace.current,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gửi yêu cầu thất bại: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _submitDaysRequest(String type, int days, String reason) async {
    try {
      final caregiverId = await AuthStorage.getUserId();
      if (caregiverId == null) throw Exception('Missing caregiverId');
      final customerId = await _getLinkedCustomerId(caregiverId);
      if (customerId == null || customerId.isEmpty) {
        AppLogger.w(
          '[CaregiverSettings] Linked customer not found for days request',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy khách hàng được liên kết.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      AppLogger.i(
        '[CaregiverSettings] Requesting days permission: type=$type, days=$days, reason=$reason',
      );
      final res = await _repo.requestDaysPermission(
        customerId: customerId,
        caregiverId: caregiverId,
        type: type,
        requestedDays: days,
        reason: reason,
      );

      AppLogger.d(
        '[CaregiverSettings] ✅ Days permission request response: $res',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã gửi yêu cầu $type ($days ngày)'),
          backgroundColor: Colors.green,
        ),
      );
      _loadPermissions();
    } catch (e) {
      AppLogger.e(
        '[CaregiverSettings] Request days permission failed: $e',
        e,
        StackTrace.current,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gửi yêu cầu thất bại: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyWidget = _loading
        ? const Center(child: CircularProgressIndicator(color: primaryBlue))
        : _buildContent();

    if (widget.embedInParent) {
      return Container(
        color: bgColor,
        child: SafeArea(
          child: Column(
            children: [
              _buildEmbeddedHeader('Quyền được chia sẻ'),
              Expanded(child: bodyWidget),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF374151),
              size: 18,
            ),
          ),
        ),
        title: const Text(
          'Quyền được chia sẻ',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: IconButton(
              onPressed: _loadPermissions,
              icon: const Icon(
                Icons.refresh,
                color: Color(0xFF64748B),
                size: 20,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: bgColor,
      body: bodyWidget,
    );
  }

  Widget _buildEmbeddedHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF007AFF),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return _permissions.isEmpty
        ? _buildEmptyState()
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _permissions.length,
            itemBuilder: (context, index) {
              final p = _permissions[index];
              return _buildPermissionCard(p);
            },
          );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: primaryBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline, size: 40, color: primaryBlue),
        ),
        const SizedBox(height: 24),
        const Text(
          'Chưa có quyền nào được chia sẻ',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _buildPermissionCard(SharedPermissions p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quyền truy cập',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildPermissionGrid([
              _PermissionItem('Xem camera', p.streamView, Icons.stream),
              _PermissionItem(
                'Đọc thông báo',
                p.alertRead,
                Icons.notifications_outlined,
              ),
              _PermissionItem(
                'Cập nhật thông báo',
                p.alertAck,
                Icons.check_circle_outline,
              ),
              _PermissionItem(
                'Xem hồ sơ bệnh nhân',
                p.profileView,
                Icons.person_outline,
              ),
            ]),
            const SizedBox(height: 20),
            _buildInfoBox(
              icon: Icons.history,
              title: 'Log',
              value: '${p.logAccessDays} ngày',
              type: 'log_access_days',
              currentValue: p.logAccessDays,
              maxValue: 7,
            ),
            const SizedBox(height: 12),
            _buildInfoBox(
              icon: Icons.assessment_outlined,
              title: 'Báo cáo',
              value: '${p.reportAccessDays} ngày',
              type: 'report_access_days',
              currentValue: p.reportAccessDays,
              maxValue: 30,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionGrid(List<_PermissionItem> items) {
    return Column(
      children: items.map((item) {
        final isEnabled = item.value == true;
        final icon = isEnabled
            ? Icons.lock_open_rounded
            : Icons.lock_outline_rounded;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isEnabled
                ? primaryBlue.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnabled
                  ? primaryBlue.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 22,
                color: isEnabled ? primaryBlue : Colors.grey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isEnabled ? Colors.black87 : Colors.grey[700],
                    fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              Icon(
                icon,
                size: 22,
                color: isEnabled ? primaryBlue : Colors.grey,
              ),
              if (!isEnabled)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: primaryBlue,
                  tooltip: 'Yêu cầu quyền truy cập',
                  onPressed: () {
                    String type;
                    switch (item.title) {
                      case 'Xem camera':
                        type = 'stream_view';
                        break;
                      case 'Đọc thông báo':
                        type = 'alert_read';
                        break;
                      case 'Cập nhật thông báo':
                        type = 'alert_ack';
                        break;
                      case 'Xem hồ sơ bệnh nhân':
                        type = 'profile_view';
                        break;
                      default:
                        type = 'unknown';
                    }
                    _showRequestDialog(
                      type: type,
                      displayName: item.title,
                      isDaysType: false,
                    );
                  },
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String title,
    required String value,
    required String type,
    required int currentValue,
    required int maxValue,
  }) {
    final canRequest = currentValue < maxValue;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: primaryBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (canRequest)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: primaryBlue),
              tooltip: 'Yêu cầu thêm quyền',
              onPressed: () => _showRequestDialog(
                type: type,
                displayName: title,
                isDaysType: true,
                maxValue: maxValue,
              ),
            ),
        ],
      ),
    );
  }
}

class _PermissionItem {
  final String title;
  final bool? value;
  final IconData icon;
  _PermissionItem(this.title, this.value, this.icon);
}
