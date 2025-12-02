import 'package:detect_care_caregiver_app/core/utils/pin_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/invitation_notification_service.dart';
import '../../auth/data/auth_storage.dart';
import '../../caregiver/data/assignment_api.dart';
import '../../caregiver/data/caregiver_api.dart';
import '../../shared_permissions/models/role_constants.dart';
import '../models/setup_step.dart';
import '../providers/setup_flow_manager.dart';

class CaregiverSetupStep extends StatefulWidget {
  const CaregiverSetupStep({super.key});

  @override
  State<CaregiverSetupStep> createState() => _CaregiverSetupStepState();
}

class _CaregiverSetupStepState extends State<CaregiverSetupStep>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final List<Map<String, dynamic>> _caregivers = [];

  bool _isInviting = false;
  String _selectedRole = roleLabelForKey('caregiver');

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _roles = setupRoleKeys
      .map((k) => roleLabelForKey(k))
      .toList();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildInviteSection(),
              const SizedBox(height: 24),
              _buildCaregiversList(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.supervisor_account_outlined,
                size: 32,
                color: Colors.white,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thiết lập người chăm sóc',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mời và phân quyền cho những người sẽ tham gia chăm sóc',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bước này có thể bỏ qua. Bạn có thể thêm người chăm sóc sau.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_add_outlined, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text(
                'Mời người chăm sóc',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _nameController,
            label: 'Họ tên người chăm sóc',
            hint: 'Nhập họ tên đầy đủ',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'Nhập địa chỉ email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            label: 'Vai trò',
            value: _selectedRole,
            items: _roles,
            onChanged: (value) => setState(() => _selectedRole = value!),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canInvite() && !_isInviting ? _inviteCaregiver : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isInviting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _isInviting ? 'Đang gửi...' : 'Thêm người chăm sóc',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiversList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_outlined, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text(
                'Danh sách người chăm sóc',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_caregivers.length} người',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_caregivers.isEmpty)
            _buildEmptyState()
          else
            ..._caregivers.map((caregiver) => _buildCaregiverCard(caregiver)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_add_disabled_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có người chăm sóc nào',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thêm người chăm sóc để bắt đầu quản lý quyền và thông báo',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverCard(Map<String, dynamic> caregiver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            child: Icon(Icons.person, color: const Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caregiver['name'] ?? '',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  caregiver['email'] ?? '',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  caregiver['role'] ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF3B82F6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(
                caregiver['status'],
              ).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getStatusText(caregiver['status']),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(caregiver['status']),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _removeCaregiver(caregiver),
            icon: const Icon(Icons.close, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              final setupManager = context.read<SetupFlowManager>();
              setupManager.completeStep(SetupStepType.caregiverSetup);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFF3B82F6)),
            ),
            icon: const Icon(Icons.skip_next_outlined),
            label: const Text(
              'Bỏ qua bước này',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _caregivers.isNotEmpty ? _completeStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check_outlined),
            label: const Text(
              'Hoàn thành',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  bool _canInvite() {
    return _nameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _isValidEmail(_emailController.text.trim());
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _inviteCaregiver() async {
    if (!_canInvite()) return;

    setState(() {
      _isInviting = true;
    });

    try {
      // Get user ID
      final userId = await AuthStorage.getUserId();
      if (userId == null || userId.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không tìm thấy thông tin người dùng. Vui lòng đăng nhập lại.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isInviting = false;
        });
        return;
      }

      // Generate random PIN
      final pin = PinUtils.generatePin(length: 6);

      // Create caregiver using real API
      final caregiverApi = CaregiverApi(
        ApiClient(tokenProvider: AuthStorage.getAccessToken),
      );
      final caregiverData = await caregiverApi.createCaregiver(
        username: _emailController.text.trim(), // Use email as username
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: '', // Phone not collected in setup
        pin: pin, // Random PIN for setup
      );

      // Create assignment between patient and caregiver
      final assignmentApi = AssignmentApi(
        ApiClient(tokenProvider: AuthStorage.getAccessToken),
      );
      await assignmentApi.createAssignment(
        customerId: userId,
        caregiverId: caregiverData['id'].toString(),
        assignmentType: 'daily_care', // Default assignment type for setup
      );

      // Send invitation email/SMS
      try {
        final notificationService = InvitationNotificationService();
        await notificationService.sendInvitation(
          recipientEmail: _emailController.text.trim(),
          recipientPhone: '', // Phone not collected in setup
          recipientName: _nameController.text.trim(),
          inviterName:
              'Người dùng hệ thống', // Could be improved to get actual user name
          invitationLink:
              'https://detectcare.app/invite/${caregiverData['id']}',
          pin: pin,
          sendEmail: true, // Always send email for now
          sendSMS: false, // SMS not implemented in setup yet
        );
        debugPrint('[CaregiverSetup] Invitation sent successfully');
      } catch (e) {
        debugPrint('[CaregiverSetup] Failed to send invitation: $e');
        // Don't fail the whole process if notification fails
      }

      final caregiver = {
        'id':
            caregiverData['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'status': 'pending', // pending, accepted, declined
        'invitedAt': DateTime.now(),
        'caregiverId': caregiverData['id']?.toString(),
      };

      setState(() {
        _caregivers.add(caregiver);
        _nameController.clear();
        _emailController.clear();
        _selectedRole = 'Người chăm sóc chính';
        _isInviting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi lời mời thành công'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isInviting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi lời mời: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeCaregiver(Map<String, dynamic> caregiver) {
    setState(() {
      _caregivers.remove(caregiver);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã xóa người chăm sóc'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _completeStep() {
    final setupManager = context.read<SetupFlowManager>();
    setupManager.completeStep(SetupStepType.caregiverSetup);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thiết lập ${_caregivers.length} người chăm sóc'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFF10B981);
      case 'declined':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'accepted':
        return 'Đã chấp nhận';
      case 'declined':
        return 'Đã từ chối';
      default:
        return 'Chờ phản hồi';
    }
  }
}
