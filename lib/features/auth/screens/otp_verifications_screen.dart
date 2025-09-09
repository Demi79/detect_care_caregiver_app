import 'dart:async';

import 'package:detect_care_caregiver_app/features/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/six_digit_input.dart';
import 'phone_login_screen.dart';

enum VerificationType { register, forgotPassword }

class OtpVerificationsScreen extends StatefulWidget {
  final String phoneNumber;
  final VerificationType verificationType;

  const OtpVerificationsScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationType,
  });

  @override
  State<OtpVerificationsScreen> createState() => _OtpVerificationsScreenState();
}

class _OtpVerificationsScreenState extends State<OtpVerificationsScreen> {
  Timer? _timer;
  int _resendCountdown = 30;
  bool _isLoading = false;
  String _otpCode = '';
  bool _initialOtpSent = false;
  String? _serverMessage;
  final _otpFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_initialOtpSent) return;
      _initialOtpSent = true;
      try {
        final auth = context.read<AuthProvider>();
        await auth.sendOtp(widget.phoneNumber);
        if (!mounted) return;
        setState(() {
          _serverMessage = auth.lastOtpRequestMessage;
          // _callId = auth.lastOtpCallId;
        });
      } catch (_) {}
    });
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendCountdown = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _onSubmit(String code) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.verifyOtp(widget.phoneNumber, code);
      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    key: const ValueKey('header'),
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF2E7BF0,
                          ).withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF2E7BF0).withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.shield_rounded,
                              color: Color(0xFF2E7BF0),
                              size: 32,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Vision AI',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Xác thực OTP để bảo vệ tài khoản của bạn',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    key: const ValueKey('otpform'),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF2E7BF0,
                          ).withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Nhập mã OTP đã gửi đến',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E3A8A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.phoneNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7BF0),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        if (_serverMessage != null &&
                            _serverMessage!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _serverMessage!,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SixDigitInputField(
                          key: _otpFieldKey,
                          onCompleted: (code) {
                            setState(() => _otpCode = code);
                            if (code.length == 6 && !_isLoading) {
                              _onSubmit(code);
                            }
                          },
                          // enablePaste: true,
                        ),
                        const SizedBox(height: 24),
                        if (_resendCountdown > 0)
                          Text(
                            'Gửi lại sau $_resendCountdown giây',
                            textAlign: TextAlign.center,
                          )
                        else
                          TextButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                final auth = context.read<AuthProvider>();
                                await auth.sendOtp(widget.phoneNumber);
                                if (!mounted) return;
                                setState(() {
                                  _serverMessage = auth.lastOtpRequestMessage;
                                  // _callId = auth.lastOtpCallId;
                                });
                                _startResendTimer();
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Gửi lại OTP thất bại: $e'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Gửi lại mã OTP'),
                          ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: (_otpCode.length == 6 && !_isLoading)
                              ? () => _onSubmit(_otpCode)
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: const Color(0xFF2E7BF0),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Xác nhận',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => PhoneLoginScreen()),
                  ),
                  child: const Text(
                    'Quay lại đăng nhập bằng số điện thoại',
                    style: TextStyle(color: Color(0xFF2E7BF0), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
