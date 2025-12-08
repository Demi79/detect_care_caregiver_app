import 'package:flutter/material.dart';
import 'completion/completion_success_icon.dart';
import 'completion/completion_summary_card.dart';
import 'completion/completion_feature_highlights.dart';
import 'completion/completion_action_buttons.dart';

class CompletionSetupStep extends StatefulWidget {
  const CompletionSetupStep({super.key});

  @override
  State<CompletionSetupStep> createState() => _CompletionSetupStepState();
}

class _CompletionSetupStepState extends State<CompletionSetupStep>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _successController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();

    // Delay success animation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _successController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                CompletionSuccessIcon(
                  animationController: _animationController,
                  successController: _successController,
                ),
                const SizedBox(height: 32),
                _buildHeader(),
                const SizedBox(height: 24),
                const CompletionSummaryCard(),
                const SizedBox(height: 24),
                const CompletionFeatureHighlights(),
                const SizedBox(height: 32),
                const CompletionActionButtons(),
                const SizedBox(height: 16),
                _buildFooterText(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Text(
            'Thiết lập hoàn tất!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Hệ thống chăm sóc sức khỏe gia đình của bạn đã được thiết lập thành công. Giờ đây bạn có thể bắt đầu sử dụng tất cả các tính năng.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterText() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Bạn có thể thay đổi cài đặt bất cứ lúc nào',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Cảm ơn bạn đã tin tưởng sử dụng VisionCare AI',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
