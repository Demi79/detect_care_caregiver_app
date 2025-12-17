part of 'action_log_card.dart';

extension _ActionLogCardHelpers on ActionLogCard {
  EventLog _buildEventLogForImages() {
    final detection = Map<String, dynamic>.from(data.detectionData);
    final context = Map<String, dynamic>.from(data.contextData);
    final cameraId = data.cameraId;
    final existingCamera =
        detection['camera_id'] ??
        detection['camera'] ??
        context['camera_id'] ??
        context['camera'];
    if ((existingCamera == null || existingCamera.toString().isEmpty) &&
        cameraId != null &&
        cameraId.isNotEmpty) {
      detection['camera_id'] = cameraId;
      context['camera_id'] = cameraId;
    }

    return EventLog(
      eventId: data.eventId,
      eventType: data.eventType,
      detectedAt: data.detectedAt,
      eventDescription: data.eventDescription,
      confidenceScore: data.confidenceScore,
      status: data.status,
      detectionData: detection,
      aiAnalysisResult: Map<String, dynamic>.from(data.aiAnalysisResult),
      contextData: context,
      boundingBoxes: Map<String, dynamic>.from(data.boundingBoxes),
      confirmStatus: data.confirmStatus,
      createdAt: data.createdAt,
      cameraId: cameraId,
    );
  }

  Future<void> _activateAlarmForEvent(
    BuildContext context,
    LogEntry event, {
    String? snapshotUrl,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final userId = await AuthStorage.getUserId();
    if (userId == null || userId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không xác thực được người dùng.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      HapticFeedback.mediumImpact();
      AppLogger.d(
        '[ActionLogCard] activating alarm for event=${event.eventId} user=$userId snapshot=$snapshotUrl',
      );
      await AlarmRemoteDataSource().setAlarm(
        eventId: event.eventId,
        userId: userId,
        cameraId: event.cameraId,
        enabled: true,
      );
      ActiveAlarmNotifier.instance.update(true);

      final rootCtx = NavigatorKey.navigatorKey.currentState?.overlay?.context;
      const successSnack = SnackBar(content: Text('Đã kích hoạt báo động'));
      if (rootCtx != null) {
        ScaffoldMessenger.of(rootCtx).showSnackBar(successSnack);
      } else {
        messenger.showSnackBar(successSnack);
      }

      try {
        final detail = await EventsRemoteDataSource().getEventById(
          eventId: event.eventId,
        );
        try {
          AppEvents.instance.notifyEventUpdated(detail);
        } catch (_) {
          AppEvents.instance.notifyEventsChanged();
        }
      } catch (_) {
        try {
          AppEvents.instance.notifyEventsChanged();
        } catch (_) {}
      }
    } catch (e) {
      final rootCtx = NavigatorKey.navigatorKey.currentState?.overlay?.context;
      final errorSnack = SnackBar(
        content: Text('Kích hoạt báo động thất bại: $e'),
        backgroundColor: Colors.red.shade600,
      );
      if (rootCtx != null) {
        ScaffoldMessenger.of(rootCtx).showSnackBar(errorSnack);
      } else {
        messenger.showSnackBar(errorSnack);
      }
    }
  }

  Future<void> _openCameraForEvent(BuildContext context, EventLog event) async {
    final messenger = ScaffoldMessenger.of(context);
    AppLogger.d('[ActionLogCard] event.cameraId = ${event.cameraId}');
    AppLogger.d(
      '[ActionLogCard] detectionData.camera_id = ${event.detectionData['camera_id']}',
    );
    AppLogger.d(
      '[ActionLogCard] contextData.camera_id = ${event.contextData['camera_id']}',
    );

    String? cameraId =
        event.cameraId ??
        event.detectionData['camera_id']?.toString() ??
        event.contextData['camera_id']?.toString();

    if (cameraId == null) {
      AppLogger.d(
        '[ActionLogCard] Không tìm thấy cameraId — đang lấy chi tiết sự kiện...',
      );
      try {
        final detail = await EventsRemoteDataSource().getEventById(
          eventId: event.eventId,
        );

        if (detail['camera_id'] != null) {
          cameraId = detail['camera_id'].toString();
          AppLogger.d(
            '[ActionLogCard] Đã tìm thấy camera_id từ top-level: $cameraId',
          );
        } else if (detail['cameras'] is Map &&
            detail['cameras']['camera_id'] != null) {
          cameraId = detail['cameras']['camera_id'].toString();
          AppLogger.d(
            '[ActionLogCard] Đã tìm thấy camera_id từ cameras object: $cameraId',
          );
        } else if (detail['snapshots'] is Map &&
            detail['snapshots']['camera_id'] != null) {
          cameraId = detail['snapshots']['camera_id'].toString();
          AppLogger.d(
            '[ActionLogCard] Đã tìm thấy camera_id từ snapshots: $cameraId',
          );
        } else {
          AppLogger.w(
            '[ActionLogCard] Không tìm thấy camera_id trong chi tiết sự kiện.',
          );
        }
      } catch (e) {
        AppLogger.e('[ActionLogCard] Lỗi khi lấy chi tiết sự kiện: $e');
      }
    }

    if (cameraId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không tìm thấy camera cho sự kiện này.')),
      );
      return;
    }

    AppLogger.d('[ActionLogCard] cameraId cuối cùng: $cameraId');

    try {
      String? customerId;
      try {
        final assignmentsDs = AssignmentsRemoteDataSource();
        final assignments = await assignmentsDs.listPending(status: 'accepted');
        final active = assignments
            .where((a) => a.isActive && (a.status.toLowerCase() == 'accepted'))
            .toList();
        if (active.isNotEmpty) customerId = active.first.customerId;
      } catch (_) {}

      customerId ??= await AuthStorage.getUserId();

      if (customerId == null || customerId.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể xác định người dùng để lấy danh sách camera.',
            ),
          ),
        );
        return;
      }

      final api = CameraApi(
        ApiClient(tokenProvider: AuthStorage.getAccessToken),
      );
      final response = await api.getCamerasByUser(userId: customerId);

      if (response['data'] is! List) {
        AppLogger.e(
          '[ActionLogCard] Cấu trúc danh sách camera không hợp lệ: ${response['data']}',
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Không thể tải danh sách camera.')),
        );
        return;
      }

      final cameras = (response['data'] as List)
          .map((e) => CameraEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      final matched = cameras.firstWhere(
        (cam) => cam.id == cameraId,
        orElse: () => cameras.first,
      );

      final cameraUrl = matched.url;
      if (cameraUrl.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Camera không có URL hợp lệ.')),
        );
        return;
      }

      final eventCustomerId = event.contextData['customer_id']?.toString();

      AppLogger.d(
        '🎬 [ActionLogCard] Mở LiveCameraScreen với url=$cameraUrl, customerId=$eventCustomerId',
      );
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveCameraScreen(
            initialUrl: cameraUrl,
            loadCache: false,
            camera: matched,
            customerId: eventCustomerId,
          ),
        ),
      );
    } catch (e) {
      AppLogger.e('[ActionLogCard] Không tải được danh sách camera: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Không thể tải danh sách camera.')),
      );
    }
  }

  Future<void> _cancelAlarmForEvent(
    BuildContext context,
    EventLog event,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final userId = await AuthStorage.getUserId();
    if (userId == null || userId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không xác thực được người dùng.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      AppLogger.d(
        '[ActionLogCard] canceling alarm for event=${event.eventId} user=$userId',
      );
      await EventsRemoteDataSource().cancelEvent(eventId: event.eventId);
      await AlarmRemoteDataSource().cancelAlarm(
        eventId: event.eventId,
        userId: userId,
        cameraId: event.cameraId,
      );
      ActiveAlarmNotifier.instance.update(false);

      final rootCtx =
          NavigatorKey.navigatorKey.currentState?.overlay?.context ?? context;
      ScaffoldMessenger.of(
        rootCtx,
      ).showSnackBar(const SnackBar(content: Text('Đã hủy báo động.')));

      try {
        AppEvents.instance.notifyEventsChanged();
      } catch (_) {}
    } catch (e) {
      final rootCtx =
          NavigatorKey.navigatorKey.currentState?.overlay?.context ?? context;
      ScaffoldMessenger.of(rootCtx).showSnackBar(
        SnackBar(
          content: Text('Hủy báo động thất bại: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }
}
