import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/fcm/services/fcm_registration.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/fcm/data/fcm_endpoints.dart';
import 'package:detect_care_caregiver_app/features/fcm/data/fcm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isEditing = false;

  final _msgCtl = TextEditingController();
  bool _sending = false;
  String? _sendLog;

  List<_CustomerOption> _customers = const [];
  String _selectedReceiver = '_ALL_';

  late final FcmRemoteDataSource _fcmDs;
  late final FcmRegistration _fcmReg;
  late final AssignmentsRemoteDataSource _assignDs;

  static const _defaultAvatarUrl =
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

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
    _fadeController.dispose();
    _scaleController.dispose();
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
            final display = (a.customerName?.trim().isNotEmpty == true)
                ? a.customerName!.trim()
                : (a.customerUsername?.trim().isNotEmpty == true
                      ? a.customerUsername!.trim()
                      : a.customerId.substring(0, 8));
            options.add(_CustomerOption(id: a.customerId, name: display));
          }
        }
      }
      options.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      if (mounted) setState(() => _customers = options);
    } catch (e) {
      debugPrint('⚠️ Load customers failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(user.phone),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName.isNotEmpty ? user.fullName : 'Chưa có tên',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildInfoRow(
                    Icons.person_outline,
                    'Họ và tên',
                    user.fullName,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.phone_outlined, 'Điện thoại', user.phone),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.email_outlined, 'Email', user.email),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.work_outline, 'Vai trò', user.role),
                  const SizedBox(height: 32),
                  _buildEditButton(),
                  const SizedBox(height: 24),

                  _fcmQuickSendCard(context, caregiverId: user.id),

                  const SizedBox(height: 24),
                  _buildLogoutButton(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Hồ sơ cá nhân',
        style: TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF374151)),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isEditing ? Icons.check : Icons.edit,
            color: _isEditing ? Colors.green : Colors.grey,
          ),
          onPressed: () => setState(() => _isEditing = !_isEditing),
        ),
      ],
    );
  }

  Widget _buildAvatar(String url) {
    final avatarUrl = url.isNotEmpty ? url : _defaultAvatarUrl;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
          width: 4,
        ),
      ),
      child: CircleAvatar(
        radius: 56,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: const Color(0xFF2E7BF0).withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
      ],
    );
  }

  Widget _buildEditButton() {
    if (!_isEditing) return const SizedBox.shrink();
    return ElevatedButton.icon(
      icon: const Icon(Icons.save),
      label: const Text('Lưu'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      onPressed: () {
        // TODO: Call API update
        setState(() => _isEditing = false);
      },
    );
  }

  // ====== CARD GỬI FCM ======
  Widget _fcmQuickSendCard(
    BuildContext context, {
    required String caregiverId,
  }) {
    const bg = Color(0xFFF8FAFC);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.send_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text(
                'Gửi thông báo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _selectedReceiver,
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem(value: '_ALL_', child: Text('Tất cả')),
              ..._customers.map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedReceiver = v ?? '_ALL_'),
            decoration: InputDecoration(
              labelText: 'Người nhận',
              filled: true,
              fillColor: bg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _msgCtl,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Nội dung…',
              filled: true,
              fillColor: bg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.notifications_active_rounded),
                  label: Text(_sending ? 'Đang gửi…' : 'Gửi'),
                  onPressed: _sending
                      ? null
                      : () => _onSendFcm(context, caregiverId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_sendLog != null) ...[
            const SizedBox(height: 8),
            Text(
              _sendLog!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onSendFcm(BuildContext context, String caregiverId) async {
    final msg = _msgCtl.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập nội dung trước khi gửi')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _fcmReg.registerForUser(caregiverId, type: 'device');
      final fromToken = await _fcmReg.getCurrentTokenSafely();

      List<String> toUserIds;
      if (_selectedReceiver == '_ALL_') {
        final list = await _assignDs.listPending();
        toUserIds = list
            .where((a) => a.status.toLowerCase() == 'accepted' && a.isActive)
            .map((a) => a.customerId)
            .toSet()
            .toList();
      } else {
        toUserIds = [_selectedReceiver];
      }

      if (toUserIds.isEmpty) {
        setState(() => _sendLog = 'Không có người nhận phù hợp');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Không có người nhận')));
        }
        return;
      }

      final resp = await _fcmDs.pushMessage(
        toUserIds: toUserIds,
        direction: 'caregiver_to_customer',
        category: 'report',
        message: msg,
        fromUserId: caregiverId,
      );

      final ok = (resp['successCount'] ?? 0).toString();
      final fail = (resp['failureCount'] ?? 0).toString();

      setState(() {
        _sendLog = 'Gửi: $ok · Lỗi: $fail';
        _msgCtl.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi: $ok · Lỗi: $fail')));
      }
    } catch (e) {
      setState(() => _sendLog = 'Lỗi: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildLogoutButton(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.logout, color: Colors.red),
      label: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Xác nhận'),
            content: const Text('Bạn có chắc muốn đăng xuất?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<AuthProvider>().logout();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CustomerOption {
  final String id;
  final String name;
  const _CustomerOption({required this.id, required this.name});
}
