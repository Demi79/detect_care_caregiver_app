class EventEndpoints {
  static const String eventsTable = 'event_detections';
  static const String eventsView = 'event_detections_view';
  static const String snapshotsTable = 'snapshots';

  static const String eventId = 'event_id';
  static const String snapshotId = 'snapshot_id';
  static const String userId = 'user_id';
  static const String cameraId = 'camera_id';
  static const String roomId = 'room_id';
  static const String confirmStatus = 'confirm_status';
  static const String eventType = 'event_type'; // enum
  static const String eventDescription = 'event_description'; // text
  static const String detectionData = 'detection_data'; // jsonb
  static const String aiAnalysisResult = 'ai_analysis_result'; // jsonb
  static const String confidenceScore = 'confidence_score'; // numeric
  static const String boundingBoxes = 'bounding_boxes'; // jsonb
  static const String status = 'status'; // enum
  static const String contextData = 'context_data'; // jsonb
  static const String detectedAt = 'detected_at'; // timestamptz
  static const String verifiedAt = 'verified_at'; // timestamptz
  static const String verifiedBy = 'verified_by'; // uuid
  static const String acknowledgedAt = 'acknowledged_at'; // timestamptz
  static const String acknowledgedBy = 'acknowledged_by'; // uuid
  static const String dismissedAt = 'dismissed_at'; // timestamptz
  static const String createdAt = 'created_at'; // timestamptz

  static const String cloudUrl = 'cloud_url';
  static const String imagePath = 'image_path';
  static const String capturedAt = 'captured_at';

  /// Select dùng cho LIST: embed luôn snapshots để lấy ảnh trong 1 request
  // static const String selectList =
  //     'event_id,event_type,event_description,confidence_score,'
  //     'status,detected_at,snapshot_id,'
  //     'snapshots($cloudUrl,$imagePath,$capturedAt)';

  static const String selectList =
      'event_id,event_type,event_description,confidence_score,'
      'status,lifecycle_state,detected_at,created_at,confirm_status';

  static const String selectDetail = selectList;

  static const List<String> defaultSelect = [
    eventId,
    status,
    eventType,
    confidenceScore,
    detectedAt,
    createdAt,
  ];

  static const List<String> detailedSelect = [
    eventId,
    snapshotId,
    userId,
    cameraId,
    roomId,
    eventType,
    eventDescription,
    detectionData,
    aiAnalysisResult,
    confidenceScore,
    boundingBoxes,
    status,
    contextData,
    detectedAt,
    verifiedAt,
    verifiedBy,
    acknowledgedAt,
    acknowledgedBy,
    dismissedAt,
    createdAt,
  ];

  static String selectCols(Iterable<String> cols) => cols.join(',');
}
