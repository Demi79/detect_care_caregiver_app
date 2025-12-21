part of 'action_log_card.dart';

extension _ActionLogCardImages on ActionLogCard {
  Future<void> _showImagesModal(BuildContext pageContext, EventLog event) {
    final permissionCustomerId =
        ActionLogCard._cachedAcceptedCustomerId ??
        data.contextData?['customer_id']?.toString();

    bool hasAlertAck = false;
    if (permissionCustomerId != null && permissionCustomerId.isNotEmpty) {
      try {
        final prov = Provider.of<PermissionsProvider>(
          pageContext,
          listen: false,
        );
        hasAlertAck = prov.hasPermission(permissionCustomerId, 'alert_ack');
      } catch (e) {
        AppLogger.w('[ActionLogCard] Image modal permission check failed: $e');
      }
    }

    final canEdit = _canEditWithContext(
      pageContext,
      customerIdOverride: permissionCustomerId,
      hasAlertAckOverride: hasAlertAck,
    );

    return buildEventImagesModal(
      pageContext: pageContext,
      event: event,
      onOpenCamera: _openCameraForEvent,
      onEdit: canEdit
          ? () {
              Navigator.push(
                pageContext,
                MaterialPageRoute(
                  builder: (_) => ProposeScreen(logEntry: data),
                ),
              );
            }
          : null,
      showEditButton: true,
      editTooltipBuilder: (enabled) =>
          enabled ? 'Cập nhật sự kiện' : _cannotEditReason,
      alarmSectionBuilder:
          (
            context,
            setDialogState,
            selectedIndex,
            selectedSource,
            isAlarmWorking,
          ) {
            final footerSelectedUrl = selectedSource?.path;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _shouldHideAlarmButtons
                        ? null
                        : () => _initiateEmergencyCall(context),
                    icon: const Icon(Icons.call),
                    label: const Text('Gọi khẩn cấp'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }

  Future<bool> _confirmAlarmDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF8FAFC),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

Future<void> showActionLogImagesModal({
  required BuildContext context,
  required EventLog event,
  Future<void> Function(BuildContext, EventLog)? onOpenCamera,
}) {
  return buildEventImagesModal(
    pageContext: context,
    event: event,
    onOpenCamera: onOpenCamera,
    showEditButton: false,
    title: 'Ảnh sự kiện',
  );
}

/// Widget builder for images - handles both local file and network URLs
Widget _buildImageWidget(dynamic imagePath) {
  // Convert ImageSource to path if needed
  final path = imagePath is ImageSource ? imagePath.path : imagePath as String;
  final isLocal = imagePath is ImageSource
      ? imagePath.isLocal
      : !path.startsWith('http');

  if (isLocal) {
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (c, e, s) {
        debugPrint('Error loading local image: $path - $e');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: Colors.grey.shade400,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'Không thể tải ảnh',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  // Network URL
  return Image.network(
    path,
    fit: BoxFit.contain,
    loadingBuilder: (c, w, progress) {
      if (progress == null) return w;
      return Center(
        child: CircularProgressIndicator(
          value: progress.expectedTotalBytes != null
              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
              : null,
        ),
      );
    },
    errorBuilder: (c, e, s) {
      debugPrint('Error loading network image: $path - $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Colors.grey.shade400,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'Không thể tải ảnh',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}

/// Helper function to build image modal for event - used by both ActionLogCard and AlertCard
Future<void> buildEventImagesModal({
  required BuildContext pageContext,
  required EventLog event,
  Future<void> Function(BuildContext, EventLog)? onOpenCamera,
  VoidCallback? onEdit,
  bool showEditButton = true,
  bool showAlarmButton = false,
  bool showEmergencyCallButton = true,
  bool allowRecordingLookup = false,
  String title = 'Hình ảnh',
  String Function(bool enabled)? editTooltipBuilder,
  Widget Function(
    BuildContext context,
    StateSetter setDialogState,
    int? selectedIndex,
    ImageSource? selectedSource,
    bool isAlarmWorking,
  )?
  alarmSectionBuilder,
}) {
  final resolveEditTooltip = editTooltipBuilder ?? (_) => 'Cập nhật sự kiện';
  // AppLogger.d('\n[ImageModal] Đang tải ảnh cho sự kiện ${event.eventId}...');
  var eventForUse = event;
  final future = (() async {
    try {
      final det = eventForUse.detectionData ?? {};
      final ctx = eventForUse.contextData ?? {};
      String? snapshotId;
      try {
        snapshotId =
            (det['snapshot_id'] ??
                    det['snapshotId'] ??
                    ctx['snapshot_id'] ??
                    ctx['snapshotId'])
                ?.toString();
      } catch (_) {
        snapshotId = null;
      }

      final eventIdKnown = eventForUse.eventId.trim().isNotEmpty;
      if (!eventIdKnown && snapshotId != null && snapshotId.isNotEmpty) {
        try {
          final resolver = EventsRemoteDataSource();
          final found = await resolver.listEvents(
            limit: 1,
            extraQuery: {'snapshot_id': snapshotId},
          );
          if (found.isNotEmpty) {
            final resolved = EventLog.fromJson(found.first);
            // AppLogger.d(
            //   '[ImageModal] Resolved event by snapshot $snapshotId -> ${resolved.eventId}',
            // );
            eventForUse = resolved;
          }
        } catch (e) {
          // AppLogger.d('[ImageModal] Snapshot->event lookup failed: $e');
        }
      }
      // Also attempt to resolve by recording_id when snapshot resolution
      // didn't provide a richer event. Some events reference recordings.
      try {
        final det = eventForUse.detectionData ?? {};
        final ctx = eventForUse.contextData ?? {};
        final recordingId =
            (det['recording_id'] ??
                    det['recordingId'] ??
                    ctx['recording_id'] ??
                    ctx['recordingId'])
                ?.toString();
        if (allowRecordingLookup &&
            (eventForUse.eventId.isEmpty ||
                (eventForUse.status ?? '').toString().trim().toLowerCase() ==
                    'unknown') &&
            recordingId != null &&
            recordingId.isNotEmpty) {
          try {
            final resolver = EventsRemoteDataSource();
            final found = await resolver.listEvents(
              limit: 1,
              extraQuery: {'recording_id': recordingId},
            );
            if (found.isNotEmpty) {
              final resolved = EventLog.fromJson(found.first);
              // AppLogger.d(
              //   '[ImageModal] Resolved event by recording $recordingId -> ${resolved.eventId}',
              // );
              eventForUse = resolved;
            }
          } catch (e) {
            // AppLogger.d('[ImageModal] recording->event lookup failed: $e');
          }
        }
      } catch (_) {}
    } catch (_) {}

    final imageSources = await loadEventImageUrls(eventForUse);
    // AppLogger.d('[ImageModal] Tìm thấy ${imageSources.length} ảnh:');
    for (var source in imageSources) {
      // AppLogger.d(' - ${source.path}');
    }
    return imageSources;
  })();

  return showDialog(
    context: pageContext,
    builder: (dialogCtx) {
      int? selectedIndex;
      bool isAlarmWorking = false;
      bool isEmergencyCalling = false;

      return StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    if (onOpenCamera != null)
                      IconButton(
                        onPressed: () {
                          final navContext = pageContext;
                          final eventData = eventForUse;
                          Navigator.of(dialogCtx).pop();
                          Future.delayed(const Duration(milliseconds: 250), () {
                            onOpenCamera(navContext, eventData);
                          });
                        },
                        icon: const Icon(Icons.videocam_outlined),
                        tooltip: 'Xem camera',
                      ),
                    if (showEditButton)
                      IconButton(
                        onPressed: onEdit != null
                            ? () {
                                if (!dialogCtx.mounted) return;
                                Navigator.of(dialogCtx).pop();
                                Future.delayed(
                                  const Duration(milliseconds: 200),
                                  () {
                                    onEdit();
                                  },
                                );
                              }
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: resolveEditTooltip(onEdit != null),
                      ),
                    // Close button
                    IconButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Main content
                Expanded(
                  child: FutureBuilder<List<ImageSource>>(
                    future: future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Text(
                            'Lỗi tải ảnh: ${snap.error}',
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        );
                      }

                      final imageSources = snap.data ?? const [];
                      if (imageSources.isEmpty) {
                        return _emptyImagesWidget();
                      }

                      selectedIndex ??= 0;
                      final selectedSource = selectedIndex != null
                          ? imageSources[selectedIndex!]
                          : null;

                      final footer = alarmSectionBuilder?.call(
                        context,
                        setDialogState,
                        selectedIndex,
                        selectedSource,
                        isAlarmWorking,
                      );

                      return Column(
                        children: [
                          Expanded(
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.3,
                                  ),
                              itemCount: imageSources.length,
                              itemBuilder: (context, index) {
                                final imageSource = imageSources[index];
                                final isSelected = selectedIndex == index;
                                return GestureDetector(
                                  onTap: () {
                                    if (!dialogCtx.mounted) return;
                                    setDialogState(() => selectedIndex = index);
                                  },
                                  child: Material(
                                    clipBehavior: Clip.antiAlias,
                                    elevation: 4,
                                    shadowColor: Colors.black.withOpacity(0.12),
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isSelected
                                            ? AppTheme.primaryBlue
                                            : Colors.grey.shade200,
                                        width: isSelected ? 3 : 1,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: _buildImageWidget(imageSource),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Color.fromRGBO(0, 0, 0, 0.7),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                            child: Text(
                                              'Ảnh ${index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Zoom icon button
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () {
                                              if (!dialogCtx.mounted) return;
                                              setDialogState(
                                                () => selectedIndex = index,
                                              );
                                              showActionLogCardImageViewer(
                                                dialogCtx,
                                                imageSources,
                                                index,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: const Color.fromRGBO(
                                                  255,
                                                  255,
                                                  255,
                                                  0.9,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.zoom_in,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (footer != null) ...[
                            const SizedBox(height: 12),
                            footer,
                          ],
                        ],
                      );
                    },
                  ),
                ),

                if (alarmSectionBuilder == null &&
                    (showAlarmButton || showEmergencyCallButton)) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showAlarmButton)
                          ValueListenableBuilder<bool>(
                            valueListenable: ActiveAlarmNotifier.instance,
                            builder: (context, alarmActive, _) {
                              final disabled =
                                  isAlarmWorking || eventForUse.eventId.isEmpty;
                              final label = alarmActive
                                  ? 'TẮT BÁO ĐỘNG'
                                  : 'KÍCH HOẠT BÁO ĐỘNG';
                              final iconData = alarmActive
                                  ? Icons.notifications_off_rounded
                                  : Icons.notifications_active_rounded;
                              final bgColor = alarmActive
                                  ? Colors.grey.shade200
                                  : Colors.red.shade50;
                              final fgColor = alarmActive
                                  ? Colors.grey.shade800
                                  : Colors.red.shade700;
                              final borderColor = alarmActive
                                  ? Colors.grey.shade400
                                  : Colors.red.shade200;

                              return SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: disabled
                                      ? null
                                      : () async {
                                          final confirmed = await showDialog<bool>(
                                            context: dialogCtx,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor: const Color(
                                                0xFFF8FAFC,
                                              ),
                                              title: Text(
                                                alarmActive
                                                    ? 'Hủy báo động'
                                                    : 'Gửi báo động?',
                                              ),
                                              content: Text(
                                                alarmActive
                                                    ? 'Bạn có chắc muốn hủy báo động?'
                                                    : 'Bạn muốn kích hoạt báo động cho sự kiện này?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(false),
                                                  child: const Text('Hủy'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(true),
                                                  child: Text(
                                                    alarmActive
                                                        ? 'Đồng ý'
                                                        : 'Gửi',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed != true) return;

                                          setDialogState(
                                            () => isAlarmWorking = true,
                                          );
                                          try {
                                            final userId =
                                                await AuthStorage.getUserId();
                                            final rootCtx =
                                                NavigatorKey
                                                    .navigatorKey
                                                    .currentState
                                                    ?.overlay
                                                    ?.context ??
                                                pageContext;

                                            if (userId == null ||
                                                userId.isEmpty) {
                                              if (!rootCtx.mounted) return;
                                              ScaffoldMessenger.of(
                                                rootCtx,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Không xác thực được người dùng.',
                                                  ),
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                ),
                                              );
                                              return;
                                            }

                                            if (alarmActive) {
                                              await EventsRemoteDataSource()
                                                  .cancelEvent(
                                                    eventId:
                                                        eventForUse.eventId,
                                                  );
                                              await AlarmRemoteDataSource()
                                                  .cancelAlarm(
                                                    eventId:
                                                        eventForUse.eventId,
                                                    userId: userId,
                                                    cameraId:
                                                        eventForUse.cameraId,
                                                  );
                                              ActiveAlarmNotifier.instance
                                                  .update(false);
                                              if (rootCtx.mounted) {
                                                ScaffoldMessenger.of(
                                                  rootCtx,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Đã hủy báo động.',
                                                    ),
                                                  ),
                                                );
                                              }
                                            } else {
                                              await AlarmRemoteDataSource()
                                                  .setAlarm(
                                                    eventId:
                                                        eventForUse.eventId,
                                                    userId: userId,
                                                    cameraId:
                                                        eventForUse.cameraId,
                                                    enabled: true,
                                                  );
                                              ActiveAlarmNotifier.instance
                                                  .update(true);
                                              if (rootCtx.mounted) {
                                                ScaffoldMessenger.of(
                                                  rootCtx,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Đã kích hoạt báo động',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            final rootCtx =
                                                NavigatorKey
                                                    .navigatorKey
                                                    .currentState
                                                    ?.overlay
                                                    ?.context ??
                                                pageContext;
                                            if (rootCtx.mounted) {
                                              ScaffoldMessenger.of(
                                                rootCtx,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    alarmActive
                                                        ? 'Hủy báo động thất bại: $e'
                                                        : 'Kích hoạt báo động thất bại: $e',
                                                  ),
                                                  backgroundColor:
                                                      Colors.red.shade600,
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (context.mounted) {
                                              setDialogState(
                                                () => isAlarmWorking = false,
                                              );
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: bgColor,
                                    foregroundColor: fgColor,
                                    elevation: 0,
                                    side: BorderSide(
                                      color: borderColor,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: isAlarmWorking
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  fgColor,
                                                ),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(iconData, size: 22),
                                            const SizedBox(width: 8),
                                            Text(
                                              label,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              );
                            },
                          ),
                        if (showAlarmButton && showEmergencyCallButton)
                          const SizedBox(height: 12),
                        if (showEmergencyCallButton)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isEmergencyCalling
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => isEmergencyCalling = true,
                                      );
                                      try {
                                        Navigator.of(dialogCtx).pop();
                                        if (!pageContext.mounted) return;
                                        await EmergencyCallHelper.initiateEmergencyCall(
                                          context,
                                        );
                                      } finally {
                                        // Dialog is closed; best-effort only.
                                        if (dialogCtx.mounted) {
                                          setDialogState(
                                            () => isEmergencyCalling = false,
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00ACC1),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: const Color(
                                  0xFF00ACC1,
                                ).withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isEmergencyCalling
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.phone_in_talk_rounded,
                                          size: 22,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'GỌI KHẨN CẤP',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Empty images placeholder widget
Widget _emptyImagesWidget() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Không có ảnh',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chưa có ảnh được ghi lại cho sự kiện này.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
      ],
    ),
  );
}
