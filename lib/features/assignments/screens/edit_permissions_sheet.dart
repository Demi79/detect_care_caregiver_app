import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/models/shared_permissions.dart';

class EditPermissionsSheet extends StatefulWidget {
  final Assignment assignment;
  final int index;

  const EditPermissionsSheet({
    super.key,
    required this.assignment,
    required this.index,
  });

  @override
  State<EditPermissionsSheet> createState() => _EditPermissionsSheetState();
}

class _EditPermissionsSheetState extends State<EditPermissionsSheet> {
  bool _streamView = false;
  bool _alertRead = false;
  bool _alertAck = false;
  bool _profileView = false;
  int _logAccessDays = 0;
  int _reportAccessDays = 0;

  @override
  void initState() {
    super.initState();
    final sp = widget.assignment.sharedPermissions;
    if (sp != null) {
      _streamView = sp['stream_view'] == true || sp['stream:view'] == true;
      _alertRead = sp['alert_read'] == true || sp['alert:read'] == true;
      _alertAck = sp['alert_ack'] == true || sp['alert:ack'] == true;
      _profileView = sp['profile_view'] == true || sp['profile:view'] == true;
      _logAccessDays = (sp['log_access_days'] is int)
          ? sp['log_access_days']
          : 0;
      _reportAccessDays = (sp['report_access_days'] is int)
          ? sp['report_access_days']
          : 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // simple toggles for the common permissions
          SwitchListTile(
            value: _streamView,
            onChanged: (v) => setState(() => _streamView = v),
            title: const Text('Xem luồng video'),
          ),
          SwitchListTile(
            value: _alertRead,
            onChanged: (v) => setState(() => _alertRead = v),
            title: const Text('Đọc cảnh báo'),
          ),
          SwitchListTile(
            value: _alertAck,
            onChanged: (v) => setState(() => _alertAck = v),
            title: const Text('Xác nhận cảnh báo'),
          ),
          SwitchListTile(
            value: _profileView,
            onChanged: (v) => setState(() => _profileView = v),
            title: const Text('Xem thông tin cá nhân'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Huỷ'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final sp = SharedPermissions(
                      caregiverId: widget.assignment.caregiverId,
                      customerId: widget.assignment.customerId,
                      streamView: _streamView,
                      alertRead: _alertRead,
                      alertAck: _alertAck,
                      logAccessDays: _logAccessDays,
                      reportAccessDays: _reportAccessDays,
                      notificationChannel: const [],
                      profileView: _profileView,
                    );
                    Navigator.pop(context, sp);
                  },
                  child: const Text('Lưu'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
