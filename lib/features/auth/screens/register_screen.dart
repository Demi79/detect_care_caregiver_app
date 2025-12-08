import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import 'otp_verifications_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  bool isAgreedToTerms = false;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FBFF), Color(0xFFF0F7FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Back Button
                    _buildBackButton(),

                    const SizedBox(height: 40),

                    // Medical Header
                    _buildMedicalHeader(),

                    const SizedBox(height: 40),

                    // Register Form
                    _buildRegisterForm(),

                    const SizedBox(height: 30),

                    // Bottom Actions
                    _buildBottomActions(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7BF0).withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF2E7BF0),
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Text(
          'Quay lại đăng nhập',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicalHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7BF0).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF2E7BF0).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: const Column(
        children: [
          // Medical Icon
          // Container(
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     color: const Color(0xFF2E7BF0).withOpacity(0.1),
          //     borderRadius: BorderRadius.circular(50),
          //   ),
          //   child: const Icon(
          //     Icons.person_add,
          //     size: 40,
          //     color: Color(0xFF2E7BF0),
          //   ),
          // ),

          // const SizedBox(height: 20),

          // Brand Name
          Text(
            'Vision AI',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A8A),
              letterSpacing: 0.5,
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Tạo tài khoản mới',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.w500,
            ),
          ),

          SizedBox(height: 4),

          Text(
            'Đăng ký để sử dụng hệ thống',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7BF0).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Form Header
            const Text(
              'Thông tin tài khoản',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A8A),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            const Text(
              'Vui lòng điền đầy đủ thông tin bên dưới',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Full Name Input
            _buildInputField(
              controller: fullNameController,
              label: 'Họ và tên',
              hintText: 'Nhập họ và tên đầy đủ',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập họ tên';
                }
                if (value.length < 2) {
                  return 'Họ tên phải có ít nhất 2 ký tự';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Phone Input
            _buildInputField(
              controller: phoneController,
              label: 'Số điện thoại',
              hintText: 'Nhập số điện thoại',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: Validators.validatePhone,
            ),

            const SizedBox(height: 24),

            // Terms and Conditions
            _buildTermsCheckbox(),

            const SizedBox(height: 32),

            Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: isAgreedToTerms
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFF2E7BF0), Color(0xFF1E40AF)],
                      )
                    : const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFF9CA3AF), Color(0xFF9CA3AF)],
                      ),
                boxShadow: isAgreedToTerms
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2E7BF0).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: ElevatedButton(
                onPressed: isAgreedToTerms && !_isLoading
                    ? () async {
                        if (_formKey.currentState?.validate() != true) return;

                        setState(() => _isLoading = true);

                        final phone = phoneController.text.trim();
                        try {
                          await context.read<AuthProvider>().sendOtp(phone);
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OtpVerificationsScreen(
                                phoneNumber: phone,
                                verificationType: VerificationType.register,
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Gửi OTP thất bại: ${e.toString()}',
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        } finally {
                          setState(() => _isLoading = false);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Tạo tài khoản',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Divider
            Row(
              children: [
                Expanded(
                  child: Container(height: 1, color: const Color(0xFFE5E7EB)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Hoặc',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(height: 1, color: const Color(0xFFE5E7EB)),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Google Register Button
            Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
                color: Colors.white,
              ),
              child: ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF374151),
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Image.asset(
                  'assets/google_logo.png',
                  width: 18,
                  height: 18,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.account_circle,
                    color: Color(0xFFDB4437),
                    size: 18,
                  ),
                ),
                label: const Text(
                  'Đăng ký với Google',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
            color: const Color(0xFFFAFBFC),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: Container(
                padding: const EdgeInsets.all(16),
                child: Icon(icon, color: const Color(0xFF2E7BF0), size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isAgreedToTerms,
              onChanged: (value) {
                setState(() {
                  isAgreedToTerms = value ?? false;
                });
              },
              activeColor: const Color(0xFF2E7BF0),
              checkColor: Colors.white,
              side: const BorderSide(color: Color(0xFF9CA3AF), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      TextSpan(text: 'Tôi đồng ý với '),
                      TextSpan(
                        text: 'Điều khoản dịch vụ',
                        style: TextStyle(
                          color: Color(0xFF2E7BF0),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      TextSpan(text: ' và '),
                      TextSpan(
                        text: 'Chính sách bảo mật',
                        style: TextStyle(
                          color: Color(0xFF2E7BF0),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      TextSpan(text: ' của Vision AI'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bao gồm việc xử lý dữ liệu y tế theo tiêu chuẩn bảo mật',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Column(
      children: [
        // Login prompt
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Đã có tài khoản? ',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Đăng nhập ngay',
                style: TextStyle(
                  color: Color(0xFF2E7BF0),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Security note
        // Container(
        //   padding: const EdgeInsets.all(16),
        //   decoration: BoxDecoration(
        //     color: const Color(0xFF10B981).withOpacity(0.05),
        //     borderRadius: BorderRadius.circular(12),
        //     border: Border.all(
        //       color: const Color(0xFF10B981).withOpacity(0.1),
        //       width: 1,
        //     ),
        //   ),
        //   child: Row(
        //     children: [
        //       const Icon(
        //         Icons.verified_user,
        //         color: Color(0xFF10B981),
        //         size: 16,
        //       ),
        //       const SizedBox(width: 8),
        //       Expanded(
        //         child: Text(
        //           'Tài khoản của bạn được bảo vệ với các tiêu chuẩn bảo mật cao nhất',
        //           style: TextStyle(
        //             color: const Color(0xFF065F46),
        //             fontSize: 12,
        //             fontWeight: FontWeight.w400,
        //           ),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
      ],
    );
  }
}
