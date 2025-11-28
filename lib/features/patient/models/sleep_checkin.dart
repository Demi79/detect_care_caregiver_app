class SleepCheckin {
  final String id;
  final String userId;
  final String date;
  final String state; // sleep | awake
  final String? source;
  final String createdAt;
  final String updatedAt;
  final String? checkinAt;
  final String? activityLogId;

  SleepCheckin({
    required this.id,
    required this.userId,
    required this.date,
    required this.state,
    required this.source,
    required this.createdAt,
    required this.checkinAt,

    required this.updatedAt,
    this.activityLogId,
  });

  factory SleepCheckin.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map? ?? {};
    return SleepCheckin(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      source: meta['source']?.toString(),
      activityLogId: meta['activity_log_id']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      checkinAt:
          json['checkin_at']?.toString() ??
          json['checkinAt']?.toString() ??
          json['created_at']?.toString(),
    );
  }
}

class SleepCheckinPage {
  final int page;
  final int limit;
  final int total;
  final List<SleepCheckin> items;

  SleepCheckinPage({
    required this.page,
    required this.limit,
    required this.total,
    required this.items,
  });

  factory SleepCheckinPage.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? [])
        .map((e) => SleepCheckin.fromJson(e as Map<String, dynamic>))
        .toList();

    return SleepCheckinPage(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? items.length,
      total: json['total'] ?? items.length,
      items: items,
    );
  }
}
