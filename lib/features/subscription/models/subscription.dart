class Subscription {
  final String id;
  final String userId;
  final String planId;
  final DateTime startedAt;
  final DateTime endsAt;
  final String status; // active, paused, cancelled
  final DateTime createdAt;
  final DateTime updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.startedAt,
    required this.endsAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['subscription_id'] ?? '',
      userId: json['user_id'] ?? '',
      planId: json['code'] ?? '',
      startedAt: DateTime.parse(
        json['started_at'] ?? DateTime.now().toIso8601String(),
      ),
      endsAt: DateTime.parse(
        json['current_period_end'] ?? DateTime.now().toIso8601String(),
      ),
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(
        json['started_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['started_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan_id': planId,
      'started_at': startedAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
