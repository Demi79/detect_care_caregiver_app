import 'package:detect_care_caregiver_app/features/setup/models/setup_step.dart';

class SetupProgress {
  final List<SetupStep> steps;
  final int currentStepIndex;
  final bool isSetupCompleted;
  final DateTime? lastUpdated;

  const SetupProgress({
    required this.steps,
    this.currentStepIndex = 0,
    this.isSetupCompleted = false,
    this.lastUpdated,
  });

  SetupStep? get currentStep {
    if (currentStepIndex >= 0 && currentStepIndex < steps.length) {
      return steps[currentStepIndex];
    }
    return null;
  }

  double get completionPercentage {
    if (steps.isEmpty) return 0.0;
    final completed = steps.where((step) => step.isCompleted).length;
    return completed / steps.length;
  }

  int get completedStepsCount {
    return steps.where((step) => step.isCompleted).length;
  }

  SetupProgress copyWith({
    List<SetupStep>? steps,
    int? currentStepIndex,
    bool? isSetupCompleted,
    DateTime? lastUpdated,
  }) {
    return SetupProgress(
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isSetupCompleted: isSetupCompleted ?? this.isSetupCompleted,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'steps': steps.map((step) => step.toJson()).toList(),
      'currentStepIndex': currentStepIndex,
      'isSetupCompleted': isSetupCompleted,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory SetupProgress.fromJson(Map<String, dynamic> json) {
    return SetupProgress(
      steps:
          (json['steps'] as List<dynamic>?)
              ?.map((stepJson) => SetupStep.fromJson(stepJson))
              .toList() ??
          [],
      currentStepIndex: json['currentStepIndex'] ?? 0,
      isSetupCompleted: json['isSetupCompleted'] ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : null,
    );
  }
}
