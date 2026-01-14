class AlarmStatus {
  final bool success;
  final bool isPlaying;
  final String? eventId;
  final List<String> activeAlarms;
  final String? audioBackend;
  final double? volume;
  final DateTime? timestamp;

  AlarmStatus({
    required this.success,
    required this.isPlaying,
    this.eventId,
    required this.activeAlarms,
    this.audioBackend,
    this.volume,
    this.timestamp,
  });

  factory AlarmStatus.fromJson(Map<String, dynamic> json) {
    final rawActive = json['active_alarms'];
    final alarms = <String>[];
    if (rawActive is List) {
      for (final item in rawActive) {
        if (item == null) continue;
        alarms.add(item.toString());
      }
    }

    double? vol;
    final rawVolume = json['volume'];
    if (rawVolume is num) {
      vol = rawVolume.toDouble();
    } else if (rawVolume is String) {
      final parsed = double.tryParse(rawVolume);
      if (parsed != null) vol = parsed;
    }

    DateTime? ts;
    final rawTs = json['timestamp'];
    if (rawTs is String) {
      ts = DateTime.tryParse(rawTs);
    }

    return AlarmStatus(
      success: json['success'] == true,
      isPlaying: json['is_playing'] == true,
      eventId: (json['event_id'] ?? json['eventId'])?.toString(),
      activeAlarms: alarms,
      audioBackend: json['audio_backend']?.toString(),
      volume: vol,
      timestamp: ts,
    );
  }

  bool isEventActive(String? eventId) {
    if (eventId == null || eventId.isEmpty) {
      return isPlaying;
    }
    final normalized = eventId.toLowerCase();
    for (final id in activeAlarms) {
      if (id.toLowerCase() == normalized) return true;
    }
    return activeAlarms.isEmpty && isPlaying;
  }
}
