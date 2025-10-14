// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
// import 'package:detect_care_caregiver_app/features/shared_permissions/data/shared_permissions_remote_data_source.dart';
// import 'package:detect_care_caregiver_app/features/shared_permissions/models/shared_permissions.dart';
// import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
// import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';

// class CaregiverSettingsScreen extends StatefulWidget {
//   final String caregiverId;
//   final String caregiverDisplay;

//   final String customerId;

//   const CaregiverSettingsScreen({
//     super.key,
//     required this.caregiverId,
//     required this.caregiverDisplay,
//     required this.customerId,
//   });

//   @override
//   State<CaregiverSettingsScreen> createState() =>
//       _CaregiverSettingsScreenState();
// }

// class _CaregiverSettingsScreenState extends State<CaregiverSettingsScreen> {
//   late final SharedPermissionsRemoteDataSource _ds;
//   late final AssignmentsRemoteDataSource _assignmentsDs;

//   Future<SharedPermissions>? _future;
//   SharedPermissions? _value;

//   @override
//   void initState() {
//     super.initState();
//     _ds = SharedPermissionsRemoteDataSource();
//     _assignmentsDs = AssignmentsRemoteDataSource();
//     _future = _load();
//   }

//   Future<String> _resolveCustomerId() async {
//     if (widget.customerId.isNotEmpty) return widget.customerId;

//     final assignments = await _assignmentsDs.listPending();
//     final acceptedCustomers = assignments
//         .where((a) => a.status.toLowerCase() == 'accepted' && a.isActive)
//         .map((a) => a.customerId)
//         .where((id) => id.isNotEmpty)
//         .toSet()
//         .toList();

//     if (acceptedCustomers.isEmpty) {
//       throw Exception(
//         'Không tìm thấy khách hàng nào đã được chấp nhận (accepted & active).',
//       );
//     }

//     return acceptedCustomers.first;
//   }

//   Future<SharedPermissions> _load() async {
//     final auth = context.read<AuthProvider>();
//     final caregiverId = widget.caregiverId.isNotEmpty
//         ? widget.caregiverId
//         : (auth.currentUserId ?? '');
//     if (caregiverId.isEmpty) {
//       throw Exception('Thiếu caregiverId (userId).');
//     }

//     final customerId = await _resolveCustomerId();
//     final data = await _ds.getSharedPermissions(
//       customerId: customerId,
//       caregiverId: caregiverId,
//     );
//     _value = data;
//     return data;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Thiết lập của bạn',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Color(0xFF1E293B),
//               ),
//             ),
//             Text(
//               widget.caregiverDisplay,
//               style: const TextStyle(
//                 fontSize: 14,
//                 color: Color(0xFF64748B),
//                 fontWeight: FontWeight.w400,
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         surfaceTintColor: Colors.transparent,
//         iconTheme: const IconThemeData(color: Color(0xFF64748B)),
//         bottom: const PreferredSize(
//           preferredSize: Size.fromHeight(1),
//           child: SizedBox(
//             height: 1,
//             child: ColoredBox(color: Color(0xFFE2E8F0)),
//           ),
//         ),
//       ),
//       body: FutureBuilder<SharedPermissions>(
//         future: _future,
//         builder: (context, snap) {
//           if (snap.connectionState != ConnectionState.done) {
//             return const Center(
//               child: CircularProgressIndicator(
//                 strokeWidth: 3,
//                 color: Color(0xFF3B82F6),
//               ),
//             );
//           }
//           if (snap.hasError) {
//             return Center(
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
//                     const SizedBox(height: 16),
//                     Text(
//                       'Lỗi: ${snap.error}',
//                       style: TextStyle(color: Colors.red[600], fontSize: 16),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           }

//           final v = _value!;
//           return SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _buildSection(
//                   title: 'Quyền truy cập',
//                   icon: Icons.security_outlined,
//                   children: [
//                     _buildSwitchTile(
//                       title: 'Xem live stream',
//                       subtitle: 'Cho phép xem camera trực tiếp',
//                       icon: Icons.videocam_outlined,
//                       value: v.streamView,
//                     ),
//                     _buildSwitchTile(
//                       title: 'Xem hồ sơ bệnh nhân',
//                       subtitle: 'Truy cập thông tin cá nhân',
//                       icon: Icons.person_outline,
//                       value: v.profileView,
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 20),
//                 _buildSection(
//                   title: 'Cảnh báo',
//                   icon: Icons.notifications_outlined,
//                   children: [
//                     _buildSwitchTile(
//                       title: 'Xem cảnh báo',
//                       subtitle: 'Có thể đọc các thông báo cảnh báo',
//                       icon: Icons.visibility_outlined,
//                       value: v.alertRead,
//                     ),
//                     _buildSwitchTile(
//                       title: 'Cập nhật cảnh báo',
//                       subtitle: 'Có thể xác nhận và cập nhật cảnh báo',
//                       icon: Icons.edit_notifications_outlined,
//                       value: v.alertAck,
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 20),
//                 _buildSection(
//                   title: 'Truy cập dữ liệu',
//                   icon: Icons.data_usage_outlined,
//                   children: [
//                     _buildNumberTile(
//                       title: 'Số ngày xem logs',
//                       subtitle: 'Thời gian truy cập lịch sử hoạt động',
//                       icon: Icons.history,
//                       value: v.logAccessDays,
//                     ),
//                     _buildNumberTile(
//                       title: 'Số ngày xem báo cáo',
//                       subtitle: 'Thời gian truy cập báo cáo tổng hợp',
//                       icon: Icons.assessment_outlined,
//                       value: v.reportAccessDays,
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 20),
//                 _buildSection(
//                   title: 'Kênh thông báo',
//                   icon: Icons.send_outlined,
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Chọn cách thức nhận thông báo',
//                             style: TextStyle(
//                               color: Color(0xFF64748B),
//                               fontSize: 14,
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//                           Wrap(
//                             spacing: 8,
//                             runSpacing: 8,
//                             children: [
//                               _buildChannelChip(
//                                 'push',
//                                 'Push',
//                                 Icons.notifications_active,
//                                 v.notificationChannel.contains('push'),
//                               ),
//                               _buildChannelChip(
//                                 'sms',
//                                 'SMS',
//                                 Icons.sms_outlined,
//                                 v.notificationChannel.contains('sms'),
//                               ),
//                               _buildChannelChip(
//                                 'email',
//                                 'Email',
//                                 Icons.email_outlined,
//                                 v.notificationChannel.contains('email'),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 const Text(
//                   'Ghi chú: Bạn không thể chỉnh sửa các thiết lập.',
//                   style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildSection({
//     required String title,
//     required IconData icon,
//     required List<Widget> children,
//   }) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: const Color(0xFF64748B).withOpacity(0.08),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: const BoxDecoration(
//               border: Border(
//                 bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
//               ),
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFF3B82F6).withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
//                 ),
//                 const SizedBox(width: 12),
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF1E293B),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           ...children,
//         ],
//       ),
//     );
//   }

//   Widget _buildSwitchTile({
//     required String title,
//     required String subtitle,
//     required IconData icon,
//     required bool value,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           Icon(icon, size: 20, color: const Color(0xFF64748B)),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w500,
//                     color: Color(0xFF1E293B),
//                   ),
//                 ),
//                 Text(
//                   subtitle,
//                   style: const TextStyle(
//                     fontSize: 13,
//                     color: Color(0xFF64748B),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Switch(
//             value: value,
//             onChanged: null,
//             activeColor: const Color(0xFF2E7BF0),
//             inactiveThumbColor: const Color(0xFF94A3B8),
//             inactiveTrackColor: const Color(0xFFE2E8F0),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildNumberTile({
//     required String title,
//     required String subtitle,
//     required IconData icon,
//     required int value,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           Icon(icon, size: 20, color: const Color(0xFF64748B)),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w500,
//                     color: Color(0xFF1E293B),
//                   ),
//                 ),
//                 Text(
//                   subtitle,
//                   style: const TextStyle(
//                     fontSize: 13,
//                     color: Color(0xFF64748B),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             width: 48,
//             alignment: Alignment.center,
//             padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
//             decoration: BoxDecoration(
//               color: const Color(0xFFF1F5F9),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Text(
//               '$value',
//               style: const TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: Color(0xFF1E293B),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildChannelChip(
//     String value,
//     String label,
//     IconData icon,
//     bool selected,
//   ) {
//     return FilterChip(
//       label: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             icon,
//             size: 16,
//             color: selected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
//           ),
//           const SizedBox(width: 4),
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//               color: selected
//                   ? const Color(0xFF3B82F6)
//                   : const Color(0xFF64748B),
//             ),
//           ),
//         ],
//       ),
//       selected: selected,
//       onSelected: null,
//       backgroundColor: Colors.white,
//       selectedColor: const Color(0xFF3B82F6).withOpacity(0.1),
//       checkmarkColor: const Color(0xFF3B82F6),
//       side: BorderSide(
//         color: selected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
//         width: 1.5,
//       ),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//     );
//   }
// }

import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/data/shared_permissions_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/models/shared_permissions.dart';
import 'package:flutter/material.dart';

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

  static const primaryBlue = Color(0xFF007AFF);
  static const bgColor = Color(0xFFF8FAFC);
  static const cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    try {
      final caregiverId = await AuthStorage.getUserId();
      if (caregiverId == null) {
        throw Exception('Missing caregiver_id');
      }
      final perms = await _repo.getByCaregiverId(caregiverId);
      setState(() {
        _permissions = perms;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Load permissions error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      // appBar: AppBar(
      //   elevation: 0,
      //   title: const Text(
      //     'Quyền được chia sẻ',
      //     style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
      //   ),
      //   backgroundColor: primaryBlue,
      //   foregroundColor: Colors.white,
      // ),
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
                return _buildPermissionCard(p, index);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
  }

  Widget _buildPermissionCard(SharedPermissions p, int index) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  // 'Quyền chia sẻ #${index + 1}',
                  'Quyền được chia sẻ ',
                  style: const TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          // Permissions Grid
          Padding(
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
                  _PermissionItem('Xem luồng', p.streamView, Icons.stream),
                  _PermissionItem(
                    'Đọc thông báo',
                    p.alertRead,
                    Icons.notifications_outlined,
                  ),
                  _PermissionItem(
                    'Xác nhận thông báo',
                    p.alertAck,
                    Icons.check_circle_outline,
                  ),
                  _PermissionItem(
                    'Xem hồ sơ',
                    p.profileView,
                    Icons.person_outline,
                  ),
                ]),

                const SizedBox(height: 20),

                // Access Days
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoBox(
                        icon: Icons.history,
                        title: 'Log',
                        value: '${p.logAccessDays ?? 0} ngày',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoBox(
                        icon: Icons.assessment_outlined,
                        title: 'Báo cáo',
                        value: '${p.reportAccessDays ?? 0} ngày',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Notification Channels
                const Text(
                  'Kênh nhận thông báo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ch in p.notificationChannel ?? <String>[])
                      _buildChannelChip(ch),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionGrid(List<_PermissionItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isEnabled = item.value == true;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isEnabled
                ? primaryBlue.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnabled
                  ? primaryBlue.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isEnabled ? primaryBlue : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isEnabled ? Colors.black87 : Colors.grey,
                    fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                isEnabled ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: isEnabled ? primaryBlue : Colors.grey,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.1), width: 1),
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
        ],
      ),
    );
  }

  Widget _buildChannelChip(String channel) {
    IconData icon;
    switch (channel.toLowerCase()) {
      case 'push':
        icon = Icons.notifications_active;
        break;
      case 'sms':
        icon = Icons.sms_outlined;
        break;
      case 'email':
        icon = Icons.email_outlined;
        break;
      default:
        icon = Icons.circle_notifications;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primaryBlue),
          const SizedBox(width: 6),
          Text(
            channel.toUpperCase(),
            style: const TextStyle(
              color: primaryBlue,
              fontWeight: FontWeight.w600,
              fontSize: 12,
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
