import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/models/user.dart'
    as auth;
import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/fcm/data/fcm_endpoints.dart';
import 'package:detect_care_caregiver_app/features/fcm/data/fcm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/fcm/services/fcm_registration.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _msgCtl = TextEditingController();
  bool _sending = false;
  String? _sendLog;
  List<_CustomerOption> _customers = const [];
  String _selectedReceiver = '_ALL_';

  late final FcmRemoteDataSource _fcmDs;
  late final FcmRegistration _fcmReg;
  late final AssignmentsRemoteDataSource _assignDs;

  @override
  void initState() {
    super.initState();

    _fcmDs = FcmRemoteDataSource(
      api: ApiClient(tokenProvider: AuthStorage.getAccessToken),
      endpoints: FcmEndpoints(AppConfig.apiBaseUrl),
    );

    _fcmReg = FcmRegistration(_fcmDs);
    _assignDs = AssignmentsRemoteDataSource();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadAcceptedCustomers(),
    );
  }

  @override
  void dispose() {
    _msgCtl.dispose();
    _fcmReg.dispose();
    super.dispose();
  }

  Future<void> _loadAcceptedCustomers() async {
    try {
      final list = await _assignDs.listPending();
      final options = <_CustomerOption>[];
      final seen = <String>{};
      for (final a in list) {
        if (a.status.toLowerCase() == 'accepted' && a.isActive) {
          if (!seen.contains(a.customerId)) {
            seen.add(a.customerId);
            options.add(
              _CustomerOption(
                id: a.customerId,
                name: a.customerName ?? 'Khách hàng ${a.customerId}',
              ),
            );
          }
        }
      }
      setState(() => _customers = options);
    } catch (e) {
      debugPrint('Error loading customers: $e');
    }
  }

  Future<void> _onSendFcm(BuildContext context, auth.User currentUser) async {
    debugPrint('🚀 [SendNotificationScreen] _onSendFcm started');

    final msg = _msgCtl.text.trim();
    debugPrint(
      '💬 [SendNotificationScreen] Message: "$msg" (length: ${msg.length})',
    );

    if (msg.isEmpty) {
      debugPrint('❌ [SendNotificationScreen] Message is empty, showing error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập nội dung trước khi gửi')),
      );
      return;
    }

    setState(() => _sending = true);
    debugPrint('⏳ [SendNotificationScreen] Setting sending state to true');

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final String direction;
      final String fromUserId;
      final List<String> toUserIds;

      debugPrint(
        '🔄 [SendNotificationScreen] Determining messaging direction...',
      );

      if (currentUser.role.toLowerCase() == 'caregiver') {
        debugPrint(
          '👨‍⚕️ [SendNotificationScreen] User is CAREGIVER - sending to customers',
        );
        direction = 'caregiver_to_customer';
        fromUserId = currentUser.id;

        debugPrint(
          '📱 [SendNotificationScreen] Registering FCM token for caregiver: ${currentUser.id}',
        );
        await _fcmReg.registerForUser(currentUser.id, type: 'device');

        debugPrint(
          '👥 [SendNotificationScreen] Selected receiver: $_selectedReceiver',
        );
        if (_selectedReceiver == '_ALL_') {
          debugPrint(
            '📋 [SendNotificationScreen] Getting all assignments for caregiver...',
          );
          final list = await _assignDs.listPending();
          debugPrint(
            '📊 [SendNotificationScreen] Retrieved ${list.length} assignments',
          );

          toUserIds = list
              .where((a) => a.status.toLowerCase() == 'accepted' && a.isActive)
              .map((a) => a.customerId)
              .toSet()
              .toList();
          debugPrint(
            '✅ [SendNotificationScreen] Filtered customers: $toUserIds',
          );
        } else {
          toUserIds = [_selectedReceiver];
          debugPrint('🎯 [SendNotificationScreen] Single receiver: $toUserIds');
        }
      } else {
        debugPrint(
          '👤 [SendNotificationScreen] User is CUSTOMER - sending to caregivers',
        );
        direction = 'customer_to_caregiver';
        fromUserId = currentUser.id;

        debugPrint(
          '📱 [SendNotificationScreen] Registering FCM token for customer: ${currentUser.id}',
        );
        await _fcmReg.registerForUser(currentUser.id, type: 'device');

        debugPrint(
          '🔍 [SendNotificationScreen] Getting assignments for customer: ${currentUser.id}',
        );
        final list = await _assignDs.listPending();
        debugPrint(
          '📊 [SendNotificationScreen] Retrieved ${list.length} total assignments',
        );

        final filteredAssignments = list
            .where(
              (a) =>
                  a.status.toLowerCase() == 'accepted' &&
                  a.isActive &&
                  a.customerId == currentUser.id,
            )
            .toList();

        debugPrint(
          '🔎 [SendNotificationScreen] Assignments for this customer: ${filteredAssignments.length}',
        );
        for (final assignment in filteredAssignments) {
          debugPrint(
            '  📝 Assignment: ${assignment.assignmentId} -> Caregiver: ${assignment.caregiverId}',
          );
        }

        toUserIds = filteredAssignments
            .map((a) => a.caregiverId)
            .toSet()
            .toList();
        debugPrint(
          '✅ [SendNotificationScreen] Final caregiver IDs: $toUserIds',
        );
      }

      debugPrint('📤 [SendNotificationScreen] Final FCM parameters:');
      debugPrint('  Direction: $direction');
      debugPrint('  From: $fromUserId');
      debugPrint('  To: $toUserIds');
      debugPrint('  Message: "$msg"');

      if (toUserIds.isEmpty) {
        final receiverType = currentUser.role.toLowerCase() == 'caregiver'
            ? 'khách hàng'
            : 'người chăm sóc';
        debugPrint(
          '❌ [SendNotificationScreen] No recipients found for $receiverType',
        );
        setState(() => _sendLog = 'Không có $receiverType phù hợp');
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Không có $receiverType nào được phân công'),
            ),
          );
        }
        return;
      }

      debugPrint('🚀 [SendNotificationScreen] Sending FCM message...');
      final resp = await _fcmDs.pushMessage(
        toUserIds: toUserIds,
        direction: direction,
        category: 'report',
        message: msg,
        fromUserId: fromUserId,
      );

      debugPrint('📨 [SendNotificationScreen] FCM response received: $resp');
      final ok = (resp['successCount'] ?? 0).toString();
      final fail = (resp['failureCount'] ?? 0).toString();
      debugPrint('✅ [SendNotificationScreen] Success: $ok, Failed: $fail');

      setState(() {
        _sendLog = 'Gửi: $ok · Lỗi: $fail';
        _msgCtl.clear();
      });

      final Map<String, dynamic> respMap = Map<String, dynamic>.from(resp);
      final Map<String, dynamic>? dataMap = respMap['data'] is Map
          ? Map<String, dynamic>.from(respMap['data'] as Map)
          : null;

      final int successCount =
          (dataMap != null
                  ? (dataMap['successCount'] ?? dataMap['success'] ?? 0)
                  : (respMap['successCount'] ?? respMap['success'] ?? 0))
              as int;
      final int failureCount =
          (dataMap != null
                  ? (dataMap['failureCount'] ?? 0)
                  : (respMap['failureCount'] ?? 0))
              as int;

      debugPrint(
        '✅ [SendNotificationScreen] Success: $successCount, Failed: $failureCount',
      );

      setState(() {
        _sendLog = 'Gửi: $successCount · Lỗi: $failureCount';
        _msgCtl.clear();
      });

      if (mounted) {
        final bool overallSuccess =
            respMap['success'] == true || successCount > 0;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              overallSuccess
                  ? 'Gửi thành công: Gửi: $successCount · Lỗi: $failureCount'
                  : 'Gửi: $successCount · Lỗi: $failureCount',
            ),
            backgroundColor: overallSuccess ? Colors.green : null,
          ),
        );
      }
      // }
    } catch (e) {
      setState(() => _sendLog = 'Lỗi: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy thông tin người dùng')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Gửi thông báo',
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.send_rounded,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Gửi thông báo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    value: _selectedReceiver,
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem(
                        value: '_ALL_',
                        child: Text('Tất cả'),
                      ),
                      ..._customers.map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedReceiver = v ?? '_ALL_'),
                    decoration: InputDecoration(
                      labelText: 'Người nhận',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _msgCtl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Nhập nội dung thông báo...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.notifications_active_rounded),
                          label: Text(_sending ? 'Đang gửi…' : 'Gửi thông báo'),
                          onPressed: _sending
                              ? null
                              : () => _onSendFcm(context, currentUser),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_sendLog != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _sendLog!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hướng dẫn',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Chọn người nhận hoặc "Tất cả" để gửi cho tất cả\n• Nhập nội dung thông báo rõ ràng\n• Thông báo sẽ được gửi qua push notification',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerOption {
  final String id;
  final String name;
  const _CustomerOption({required this.id, required this.name});
}
