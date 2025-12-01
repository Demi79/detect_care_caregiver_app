import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/data/shared_permissions_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/models/shared_permissions.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CaregiverSettingsScreen extends StatefulWidget {
  const CaregiverSettingsScreen({super.key});

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

  @override
  void initState() {
    super.initState();
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
      final perms = await _repo.getByCaregiverId(caregiverId);
      setState(() {
        _permissions = perms;
        _loading = false;
      });
    } catch (e) {
      print('❌ Load permissions error: $e');
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
      if (caregiverId == null) return;

      final client = Supabase.instance.client as dynamic;

      try {
        _permSub = client
            .from('permissions')
            .on('INSERT', (payload) => _onRealtimePayload(payload, caregiverId))
            .on('UPDATE', (payload) => _onRealtimePayload(payload, caregiverId))
            .on('DELETE', (payload) => _onRealtimePayload(payload, caregiverId))
            .subscribe();
      } catch (_) {
        // older/newer supabase client variants may have different APIs; ignore
      }

      try {
        _inviteSub = client
            .from('caregiver_invitations')
            .on('INSERT', (payload) => _onRealtimePayload(payload, caregiverId))
            .on('UPDATE', (payload) => _onRealtimePayload(payload, caregiverId))
            .on('DELETE', (payload) => _onRealtimePayload(payload, caregiverId))
            .subscribe();
      } catch (_) {}
    } catch (e) {
      debugPrint('Realtime subscription setup failed: $e');
    }
  }

  void _onRealtimePayload(dynamic payload, String caregiverId) {
    try {
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
        // payload shape unknown, try accessing common fields
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

      if (eventCaregiverId == null || eventCaregiverId == caregiverId) {
        _scheduleReload();
      }
    } catch (_) {
      _scheduleReload();
    }
  }

  void _scheduleReload() {
    _debounceReloadTimer?.cancel();
    _debounceReloadTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _loadPermissions();
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
                  decoration: InputDecoration(
                    labelText: 'Số ngày muốn yêu cầu',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Lý do yêu cầu',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 2,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy khách hàng được liên kết.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final res = await _repo.createPermissionRequest(
        customerId: customerId,
        caregiverId: caregiverId,
        type: type,
        requestedBool: true,
        scope: 'read',
        reason: reason,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã gửi yêu cầu quyền $type'),
          backgroundColor: Colors.green,
        ),
      );
      debugPrint('✅ Response: $res');
      _loadPermissions();
    } catch (e) {
      debugPrint('❌ Request permission failed: $e');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy khách hàng được liên kết.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final res = await _repo.requestDaysPermission(
        customerId: customerId,
        caregiverId: caregiverId,
        type: type,
        requestedDays: days,
        reason: reason,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã gửi yêu cầu $type ($days ngày)'),
          backgroundColor: Colors.green,
        ),
      );
      debugPrint('✅ Response: $res');
      _loadPermissions();
    } catch (e) {
      debugPrint('❌ Request days permission failed: $e');
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            )
          : _permissions.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _permissions.length,
              itemBuilder: (context, index) {
                final p = _permissions[index];
                return _buildPermissionCard(p);
              },
            ),
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
