class LogEntry {
  final String eventId;
  final String status;
  final String eventType;
  final String? eventDescription;
  final String? notes;
  final String? cameraId;
  final double confidenceScore;
  final DateTime? detectedAt;
  final DateTime? createdAt;
  final Map<String, dynamic> detectionData;
  final Map<String, dynamic> aiAnalysisResult;
  final Map<String, dynamic> contextData;
  final Map<String, dynamic> boundingBoxes;
  final String? lifecycleState;
  final String? createBy;
  final bool? hasEmergencyCall;
  final bool? hasAlarmActivated;
  final String? lastEmergencyCallSource;
  final String? lastAlarmActivatedSource;
  final DateTime? lastEmergencyCallAt;
  final DateTime? lastAlarmActivatedAt;
  final bool? isAlarmTimeoutExpired;

  final bool confirmStatus;

  LogEntry({
    required this.eventId,
    required this.status,
    required this.eventType,
    this.eventDescription,
    this.notes,
    this.cameraId,
    required this.confidenceScore,
    this.detectedAt,
    this.createdAt,
    this.detectionData = const {},
    this.aiAnalysisResult = const {},
    this.contextData = const {},
    this.boundingBoxes = const {},
    this.lifecycleState,
    this.createBy,
    this.hasEmergencyCall,
    this.hasAlarmActivated,
    this.lastEmergencyCallSource,
    this.lastAlarmActivatedSource,
    this.lastEmergencyCallAt,
    this.lastAlarmActivatedAt,
    this.isAlarmTimeoutExpired,
    required this.confirmStatus,
  });
}
