import 'package:flutter/material.dart';
import '../model/user_profile.dart';
import '../services/user_services.dart';

class EditUserScreen extends StatefulWidget {
  final UserProfile user;
  final UsersService service;

  const EditUserScreen({super.key, required this.user, required this.service});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usernameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _fullNameCtrl;
  late TextEditingController _phoneCtrl;

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

    _usernameCtrl = TextEditingController(text: widget.user.username);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _fullNameCtrl = TextEditingController(text: widget.user.fullName);
    _phoneCtrl = TextEditingController(text: widget.user.phoneNumber);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final newUsername = sanitize(_usernameCtrl.text);
    final newEmail = sanitize(_emailCtrl.text);
    final newFullName = sanitize(_fullNameCtrl.text);
    final newPhone = sanitize(_phoneCtrl.text);

    final Map<String, dynamic> delta = {};
    if (newUsername != widget.user.username) delta['username'] = newUsername;
    if (newEmail != widget.user.email) delta['email'] = newEmail;
    if (newFullName != widget.user.fullName) delta['full_name'] = newFullName;
    if (newPhone != widget.user.phoneNumber) delta['phone_number'] = newPhone;

    if (delta.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Không có thay đổi'),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      setState(() => _loading = false);
      Navigator.pop(context, false);
      return;
    }

    try {
      final result = await widget.service.updateUserFields(
        widget.user.userId,
        delta,
      );

      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (err) {
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  String sanitize(String v) {
    return v.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Widget build(BuildContext context) {
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
          'Cập nhật thông tin',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đang cập nhật...',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ],
              ),
            )
          : _form(),
    );
  }

  Widget _form() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryBlue, Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chỉnh sửa thông tin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cập nhật thông tin cá nhân của bạn',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Error Message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Form Section Title
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: lightBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Thông tin cá nhân',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Form Container
            Container(
              padding: const EdgeInsets.all(20),
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
                children: [
                  _input("Họ tên", _fullNameCtrl, icon: Icons.person_outline),
                  const SizedBox(height: 16),
                  _input(
                    "Email",
                    _emailCtrl,
                    keyboard: TextInputType.emailAddress,
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),
                  _input(
                    "Tên đăng nhập",
                    _usernameCtrl,
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),
                  _input(
                    "Số điện thoại",
                    _phoneCtrl,
                    keyboard: TextInputType.phone,
                    icon: Icons.phone_outlined,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: primaryBlue, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'Lưu thay đổi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
              ],
            ),

            const SizedBox(height: 20),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: lightBlue),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: primaryBlue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chỉ những trường đã thay đổi mới được cập nhật',
                      style: TextStyle(fontSize: 13, color: textSecondary),
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

  Widget _input(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
    required IconData icon,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: (v) => v == null || v.trim().isEmpty ? "Không để trống" : null,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: primaryBlue, size: 22),
        filled: true,
        fillColor: backgroundColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
      ),
    );
  }
}
