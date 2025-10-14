class ConsentPolicy {
  final String id;
  final String type;
  final String title;
  final String content;
  final String version;
  final bool isRequired;
  final bool isActive;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final Map<String, dynamic>? metadata;

  const ConsentPolicy({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.version,
    required this.isRequired,
    required this.isActive,
    required this.effectiveFrom,
    this.effectiveTo,
    this.metadata,
  });

  factory ConsentPolicy.fromJson(Map<String, dynamic> json) {
    return ConsentPolicy(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      version: json['version']?.toString() ?? '1.0',
      isRequired: json['is_required'] ?? false,
      isActive: json['is_active'] ?? true,
      effectiveFrom: DateTime.parse(
        json['effective_from'] ?? DateTime.now().toIso8601String(),
      ),
      effectiveTo: json['effective_to'] != null
          ? DateTime.parse(json['effective_to'])
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'content': content,
    'version': version,
    'is_required': isRequired,
    'is_active': isActive,
    'effective_from': effectiveFrom.toIso8601String(),
    'effective_to': effectiveTo?.toIso8601String(),
    'metadata': metadata,
  };

  ConsentPolicy copyWith({
    String? id,
    String? type,
    String? title,
    String? content,
    String? version,
    bool? isRequired,
    bool? isActive,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    Map<String, dynamic>? metadata,
  }) {
    return ConsentPolicy(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      version: version ?? this.version,
      isRequired: isRequired ?? this.isRequired,
      isActive: isActive ?? this.isActive,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isExpired =>
      effectiveTo != null && DateTime.now().isAfter(effectiveTo!);
  bool get isEffective => isActive && !isExpired;
}
