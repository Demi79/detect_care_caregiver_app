import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/setup_flow_manager.dart';
import '../models/setup_step.dart';
import '../widgets/welcome_setup_step.dart';
import '../widgets/patient_profile_setup_step.dart';
import '../widgets/caregiver_setup_step.dart';
import '../widgets/image_settings_setup_step.dart';
import '../widgets/alert_settings_setup_step.dart';
import '../widgets/completion_setup_step.dart';

class HouseholdSetupScreen extends StatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  State<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends State<HouseholdSetupScreen>
    with TickerProviderStateMixin {
  late final SetupFlowManager _setupManager;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupManager = SetupFlowManager();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _initializeSetup();
  }

  Future<void> _initializeSetup() async {
    await _setupManager.initialize(context);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _setupManager,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Consumer<SetupFlowManager>(
              builder: (context, manager, child) {
                if (manager.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (manager.error != null) {
                  return _buildErrorState(manager.error!);
                }

                return _buildSetupFlow(manager);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Đã xảy ra lỗi',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _setupManager.initialize(context),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupFlow(SetupFlowManager manager) {
    final currentStep = manager.currentStep;
    if (currentStep == null) {
      return _buildErrorState('Không tìm thấy bước setup');
    }

    return Column(
      children: [
        _buildHeader(manager),
        _buildProgressIndicator(manager),
        Expanded(child: _buildStepContent(currentStep, manager)),
        _buildNavigationBar(manager),
      ],
    );
  }

  Widget _buildHeader(SetupFlowManager manager) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner when patient profile was auto-skipped
          if (manager.autoSkippedPatientProfile)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Dismissible(
                key: const ValueKey('autoSkipPatientBanner'),
                direction: DismissDirection.up,
                onDismissed: (_) {},
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBEE3F8)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Color(0xFF0EA5E9)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hồ sơ bệnh nhân đã có sẵn — bước này được bỏ qua.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7BF0), Color(0xFF06B6D4)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.home_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thiết lập gia đình',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Cấu hình hệ thống chăm sóc sức khỏe',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showSkipSetupDialog(context, manager),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                ),
                child: const Text(
                  'Bỏ qua',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(SetupFlowManager manager) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${manager.progress.completedStepsCount}/${manager.progress.steps.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: manager.completionPercentage,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7BF0)),
          ),
          const SizedBox(height: 12),
          Text(
            '${(manager.completionPercentage * 100).toInt()}% hoàn thành',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(SetupStep step, SetupFlowManager manager) {
    switch (step.type) {
      case SetupStepType.welcome:
        return const WelcomeSetupStep();
      case SetupStepType.patientProfile:
        return const PatientProfileSetupStep();
      case SetupStepType.caregiverSetup:
        return const CaregiverSetupStep();
      case SetupStepType.imageSettings:
        return const ImageSettingsSetupStep();
      case SetupStepType.alertSettings:
        return const AlertSettingsSetupStep();
      case SetupStepType.completion:
        return const CompletionSetupStep();
    }
  }

  Widget _buildNavigationBar(SetupFlowManager manager) {
    final currentStep = manager.currentStep;
    if (currentStep == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main Navigation Row
          Row(
            children: [
              if (manager.hasPreviousStep) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => manager.previousStep(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Quay lại'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],

              if (currentStep.isSkippable && !currentStep.isCompleted) ...[
                Expanded(
                  child: TextButton(
                    onPressed: () => manager.skipCurrentStep(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Bỏ qua bước'),
                  ),
                ),
                const SizedBox(width: 16),
              ],

              Expanded(
                flex: currentStep.isSkippable ? 1 : 2,
                child: ElevatedButton.icon(
                  onPressed:
                      manager.canProceedToNextStep() || currentStep.isCompleted
                      ? () => _handleNextStep(manager)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7BF0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    manager.hasNextStep ? Icons.arrow_forward : Icons.check,
                  ),
                  label: Text(manager.hasNextStep ? 'Tiếp tục' : 'Hoàn thành'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleNextStep(SetupFlowManager manager) {
    if (manager.hasNextStep) {
      manager.nextStep();
    } else {
      manager.completeSetup(context);
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _showSkipSetupDialog(BuildContext context, SetupFlowManager manager) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.skip_next_outlined, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 12),
            Text('Bỏ qua thiết lập?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có chắc chắn muốn bỏ qua quá trình thiết lập?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text(
              'Lưu ý:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF59E0B),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• Bạn có thể thiết lập lại trong phần Cài đặt\n'
              '• Một số tính năng có thể hoạt động không tối ưu\n'
              '• Khuyến nghị hoàn thành thiết lập để trải nghiệm tốt nhất',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext loadingContext) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Đang bỏ qua thiết lập...'),
                    ],
                  ),
                ),
              );

              try {
                await manager.skipSetup();
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading dialog
                  _navigateToHome();

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Đã bỏ qua thiết lập. Bạn có thể thiết lập lại trong Cài đặt.',
                      ),
                      backgroundColor: Color(0xFF10B981),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Bỏ qua'),
          ),
        ],
      ),
    );
  }

  // Step content builders
}
