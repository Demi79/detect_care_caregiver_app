import 'package:detect_care_caregiver_app/features/profile/model/user_profile.dart';
import 'package:detect_care_caregiver_app/features/profile/repositories/user_repositories.dart';
import 'package:detect_care_caregiver_app/features/profile/screens/edit_user_screen.dart';
import 'package:detect_care_caregiver_app/features/profile/services/user_services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/profile/data/user_remote_data_source.dart';
import 'package:detect_care_caregiver_app/core/providers/permissions_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final UsersService? service;
  final bool embedInParent;

  const ProfileScreen({
    super.key,
    this.userId,
    this.service,
    this.embedInParent = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _user;
  bool _loading = false;
  String? _error;

  static const primaryBlue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFFDEEBFF);
  static const backgroundColor = Color(0xFFF8FAFC);
  static const cardColor = Colors.white;
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = widget.userId ?? await AuthStorage.getUserId();
      if (uid == null || uid.isEmpty) {
        throw Exception('Không tìm thấy userId');
      }

      final svc =
          widget.service ??
          UsersService(
            UsersRepository(
              UsersRemoteDataSource(
                ApiClient(tokenProvider: AuthStorage.getAccessToken),
              ),
            ),
          );

      final data = await svc.getUserInfo(uid);
      setState(() {
        _user = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _goToEdit() {
    if (_user == null) return;
    final svc =
        widget.service ??
        UsersService(
          UsersRepository(
            UsersRemoteDataSource(
              ApiClient(tokenProvider: AuthStorage.getAccessToken),
            ),
          ),
        );

    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(
            builder: (_) => EditUserScreen(user: _user!, service: svc),
          ),
        )
        .then((updated) {
          if (updated == true) {
            _loadUser();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Cập nhật thông tin thành công'),
                  backgroundColor: primaryBlue,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          }
        });
  }

  Future<void> _onLogoutPressed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi ứng dụng không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      try {
        final permProvider = context.read<PermissionsProvider>();
        permProvider.reset();
      } catch (e) {
        debugPrint('Logout: error resetting permissions provider: $e');
      }

      await AuthStorage.clear();
    } catch (e) {
      debugPrint('Logout: error clearing auth storage: $e');
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đăng xuất'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Try to navigate to a known login route; if the route doesn't exist,
    // fall back to popping to the first route in the stack.
    try {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    } catch (_) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final bodyWidget = _body(u);

    if (widget.embedInParent) {
      return Container(
        color: backgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              _buildEmbeddedHeader('Hồ sơ cá nhân'),
              Expanded(child: bodyWidget),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
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
          'Thông tin tài khoản',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
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

  Widget _body(UserProfile? u) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Lỗi tải dữ liệu",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadUser,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (u == null) {
      return const Center(child: Text("Không có dữ liệu người dùng"));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header Card with Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: primaryBlue,
            child: Text(
              u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            u.fullName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 20),

          // Personal Information Section
          _buildSection(
            title: "Thông tin cá nhân",
            icon: Icons.person_outline,
            children: [
              _buildInfoCard(
                icon: Icons.badge_outlined,
                label: "Username",
                value: u.username,
              ),
              _buildInfoCard(
                icon: Icons.phone_outlined,
                label: "Số điện thoại",
                value: u.phoneNumber,
              ),
              _buildInfoCard(
                icon: Icons.email_outlined,
                label: "Email",
                value: u.email,
              ),
              _buildInfoCard(
                icon: Icons.calendar_today_outlined,
                label: "Ngày tham gia",
                value: _formatJoined(u.joined),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Edit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _goToEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text(
                'Chỉnh sửa thông tin',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),

          // const SizedBox(height: 20),

          // Service Plan Section
          // _buildSection(
          //   title: "Gói dịch vụ",
          //   icon: Icons.workspace_premium_outlined,
          //   children: [
          //     _buildInfoCard(
          //       icon: Icons.card_membership_outlined,
          //       label: "Gói",
          //       value: "${u.planName} (${u.planCode})",
          //       valueColor: primaryBlue,
          //     ),
          //     _buildInfoCard(
          //       icon: Icons.videocam_outlined,
          //       label: "Camera tối đa",
          //       value: "${u.cameraQuota}",
          //     ),
          //     _buildInfoCard(
          //       icon: Icons.videocam,
          //       label: "Camera đã dùng",
          //       value: '${u.cameraQuotaUsed == 0 ? 2 : u.cameraQuotaUsed}',
          //       valueColor: u.cameraQuotaUsed >= u.cameraQuota
          //           ? Colors.red.shade600
          //           : null,
          //     ),
          //     // _buildInfoCard(
          //     //   icon: Icons.check_circle_outline,
          //     //   label: "Tình trạng",
          //     //   value: u.subscriptionStatus,
          //     //   valueColor:
          //     //       u.subscriptionStatus.toLowerCase().contains('active')
          //     //       ? Colors.green.shade600
          //     //       : Colors.orange.shade600,
          //     // ),
          //   ],
          // ),
          const SizedBox(height: 20),
          // Logout button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _onLogoutPressed,
              icon: const Icon(Icons.logout_outlined),
              label: const Text('Đăng xuất'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 20),
          // Statistics Row
          // Row(
          //   children: [
          //     Expanded(
          //       child: _buildStatCard(
          //         icon: Icons.notifications_active_outlined,
          //         title: "Cảnh báo",
          //         total: u.alertsTotal,
          //         subtitle: "${u.alertsUnresolved} chưa xử lý",
          //         color: Colors.orange,
          //       ),
          //     ),
          //     const SizedBox(width: 12),
          //     Expanded(
          //       child: _buildStatCard(
          //         icon: Icons.payment_outlined,
          //         title: "Thanh toán",
          //         total: u.paymentsTotal,
          //         subtitle: "${u.paymentsPending} đang chờ",
          //         color: Colors.green,
          //       ),
          //     ),
          //   ],
          // ),

          // const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: primaryBlue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: valueColor ?? textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required int total,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$total',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: textSecondary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _formatJoined(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      final local = dt.toLocal();
      return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    } catch (_) {
      return raw;
    }
  }
}
