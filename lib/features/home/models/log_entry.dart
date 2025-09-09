class LogEntry {
  final String eventId;
  final String status;
  final String eventType;
  final String? eventDescription;
  final double confidenceScore;
  final DateTime? detectedAt;
  final DateTime? createdAt;
  final Map<String, dynamic> detectionData;
  final Map<String, dynamic> aiAnalysisResult;
  final Map<String, dynamic> contextData;
  final Map<String, dynamic> boundingBoxes;

  final bool confirmStatus;

  LogEntry({
    required this.eventId,
    required this.status,
    required this.eventType,
    this.eventDescription,
    required this.confidenceScore,
    this.detectedAt,
    this.createdAt,
    this.detectionData = const {},
    this.aiAnalysisResult = const {},
    this.contextData = const {},
    this.boundingBoxes = const {},
    required this.confirmStatus,
  });
}
