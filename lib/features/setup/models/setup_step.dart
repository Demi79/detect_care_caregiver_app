enum SetupStepType {
  welcome,
  patientProfile,
  caregiverSetup,
  imageSettings,
  alertSettings,
  completion,
}

class SetupStep {
  final SetupStepType type;
  final String title;
  final String description;
  final bool isCompleted;
  final bool isSkippable;
  final int order;

  const SetupStep({
    required this.type,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.isSkippable = false,
    required this.order,
  });

  SetupStep copyWith({
    SetupStepType? type,
    String? title,
    String? description,
    bool? isCompleted,
    bool? isSkippable,
    int? order,
  }) {
    return SetupStep(
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      isSkippable: isSkippable ?? this.isSkippable,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'isSkippable': isSkippable,
      'order': order,
    };
  }

  factory SetupStep.fromJson(Map<String, dynamic> json) {
    return SetupStep(
      type: SetupStepType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SetupStepType.welcome,
      ),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
      isSkippable: json['isSkippable'] ?? false,
      order: json['order'] ?? 0,
    );
  }
}
