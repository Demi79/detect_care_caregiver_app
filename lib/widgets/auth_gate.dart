import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/auth/screens/email_login_screen.dart';
import 'package:detect_care_caregiver_app/features/auth/screens/otp_verifications_screen.dart';
import 'package:detect_care_caregiver_app/features/home/screens/home_screen.dart';
import 'package:detect_care_caregiver_app/features/home/screens/pending_assignment_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        switch (auth.status) {
          case AuthStatus.loading:
            return const LoadingGate();
          case AuthStatus.unauthenticated:
            return const EmailLoginScreen();
          case AuthStatus.otpSent:
            return OtpVerificationsScreen(
              phoneNumber: auth.pendingPhone!,
              verificationType: VerificationType.register,
            );
          case AuthStatus.assignVerified:
            // Caregiver login xong nhưng:
            // - Chưa được assign (isAssigned = false) HOẶC
            // - Chưa active (isActive = false)
            return const PendingAssignmentsScreen();
          case AuthStatus.authenticated:
            // Caregiver đã:
            // - Được assign (isAssigned = true) VÀ
            // - Đã active (isActive = true)
            return const HomeScreen();
        }
      },
    );
  }
}

class LoadingGate extends StatefulWidget {
  const LoadingGate({super.key});
  @override
  State<LoadingGate> createState() => _LoadingGateState();
}

class _LoadingGateState extends State<LoadingGate> {
  @override
  void initState() {
    super.initState();
    // Safety timeout: nếu còn loading sau 8s thì reset
    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.status == AuthStatus.loading) {
        auth.resetToUnauthenticated();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
