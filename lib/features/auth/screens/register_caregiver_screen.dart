import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/caregiver/data/caregiver_api.dart';
import 'package:flutter/material.dart';

class RegisterCaregiverScreen extends StatefulWidget {
  const RegisterCaregiverScreen({super.key});

  @override
  State<RegisterCaregiverScreen> createState() =>
      _RegisterCaregiverScreenState();
}

class _RegisterCaregiverScreenState extends State<RegisterCaregiverScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  bool loading = false;
  String? error;
  late final CaregiverApi caregiverApi;

  @override
  void initState() {
    super.initState();
    caregiverApi = CaregiverApi(
      ApiClient(tokenProvider: AuthStorage.getAccessToken),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await caregiverApi.createCaregiver(
        username: usernameController.text.trim(),
        fullName: fullNameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        pin: pinController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký caregiver thành công!')),
      );
      Navigator.pop(context, result);
    } catch (e) {
      setState(() {
        error = 'Đăng ký thất bại: $e';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(top: 14),
          // child: Text('Đăng ký Caregiver'),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.only(left: 28, top: 14),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF64748B),
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 22,
                ),
              )
            : null,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7BF0), Color(0xFF06B6D4), Color(0xFFB2F5EA)],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 38),
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    padding: const EdgeInsets.only(
                      top: 66,
                      left: 24,
                      right: 24,
                      bottom: 24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, 0.95),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(33, 150, 243, 0.18),
                          blurRadius: 40,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(33, 150, 243, 0.5),
                                blurRadius: 32,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 28,
                            backgroundColor: Color(0xFF2E7BF0),
                            child: Icon(
                              Icons.volunteer_activism,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Đăng ký tài khoản Caregiver',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Caregiver là người hỗ trợ, chăm sóc và nhận thông báo về sức khỏe bệnh nhân trong hệ thống Vision AI.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(6, 182, 212, 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            '“Chăm sóc là sức mạnh của sự kết nối và yêu thương.”',
                            style: TextStyle(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF0E7490),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 38),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: const Color(0xFF2E7BF0),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(33, 150, 243, 0.18),
                        blurRadius: 32,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInputField(
                          controller: usernameController,
                          label: 'Username',
                          icon: Icons.account_circle_outlined,
                          keyboardType: TextInputType.text,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Nhập username' : null,
                        ),
                        const SizedBox(height: 18),
                        _buildInputField(
                          controller: fullNameController,
                          label: 'Họ và tên đầy đủ',
                          icon: Icons.person_outline,
                          keyboardType: TextInputType.text,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Nhập họ và tên đầy đủ'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        _buildInputField(
                          controller: emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Nhập email' : null,
                        ),
                        const SizedBox(height: 18),
                        _buildInputField(
                          controller: phoneController,
                          label: 'Số điện thoại',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Nhập số điện thoại'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        _buildInputField(
                          controller: pinController,
                          label: 'PIN (6 ký tự)',
                          icon: Icons.lock_outline,
                          keyboardType: TextInputType.text,
                          obscureText: true,
                          validator: (v) => v == null || v.length < 5
                              ? 'PIN tối thiểu 6 ký tự'
                              : null,
                        ),
                        const SizedBox(height: 26),
                        if (error != null) ...[
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style:
                                ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  elevation: 0,
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                ).copyWith(
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith<Color?>(
                                        (states) => null,
                                      ),
                                ),
                            onPressed: loading ? null : _submit,
                            icon: loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF06B6D4),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.volunteer_activism,
                                    color: Color(0xFF06B6D4),
                                  ),
                            label: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return const LinearGradient(
                                  colors: [
                                    Color(0xFF2E7BF0),
                                    Color(0xFF06B6D4),
                                  ],
                                ).createShader(bounds);
                              },
                              child: const Text(
                                'Đăng ký caregiver',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    return FocusScope(
      child: Focus(
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            return TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              obscureText: obscureText,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(
                  icon,
                  color: hasFocus
                      ? const Color(0xFF2E7BF0)
                      : const Color(0xFF64748B),
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: Color(0xFF2E7BF0), width: 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
