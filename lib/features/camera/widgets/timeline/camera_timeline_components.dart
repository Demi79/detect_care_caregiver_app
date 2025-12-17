import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:detect_care_caregiver_app/core/providers/permissions_provider.dart';
import 'package:detect_care_caregiver_app/core/utils/event_edit_validation.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:provider/provider.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/events/screens/propose_screen.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_images_loader.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';

import 'package:flutter/material.dart';

import 'timeline_models.dart';
import 'timeline_utils.dart';
import 'timeline_mapper.dart';
export 'timeline_utils.dart';
export 'timeline_models.dart';

EventLog _buildTimelineEventLog(CameraTimelineClip clip, CameraEntry camera) =>
    buildTimelineEventLog(clip, camera);

bool _timelineCanEdit(EventLog event) => timelineCanEdit(
  EventLogLike(createdAt: event.createdAt, detectedAt: event.detectedAt),
);

class CameraTimelineModeOption {
  final IconData icon;
  final String label;

  const CameraTimelineModeOption(this.icon, this.label);
}

/// Small chip used by the mode selector row. Shows an icon and optional label.
class CameraTimelineModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  const CameraTimelineModeChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.orange.shade700 : Colors.transparent;
    final textColor = selected ? Colors.white : Colors.grey.shade800;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small circular button used in date selector and other compact controls.
class CameraTimelineCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool enabled;

  const CameraTimelineCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: enabled ? Colors.grey.shade100 : Colors.grey.shade50,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: enabled ? Colors.grey.shade800 : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }
}

class CameraTimelineRow extends StatelessWidget {
  final CameraTimelineEntry entry;
  final bool isSelected;
  final VoidCallback? onClipTap;
  final CameraEntry camera;

  const CameraTimelineRow({
    super.key,
    required this.entry,
    required this.isSelected,
    this.onClipTap,
    required this.camera,
  });

  @override
  Widget build(BuildContext context) {
    final hasClip = entry.clip != null;
    final clipHeight = 96.0 + 16 + 10;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, left: 6, right: 6),
            child: hasClip
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.orange.shade700
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.clip!.timeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : Text(
                    entry.timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 30,
          child: Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isSelected && hasClip
                      ? Colors.deepOrange
                      : Colors.grey.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    if (isSelected && hasClip)
                      BoxShadow(
                        color: Colors.orange.withOpacitySafe(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: clipHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade300, Colors.grey.shade200],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: hasClip
              ? CameraTimelineClipCard(
                  clip: entry.clip!,
                  selected: isSelected,
                  onTap: onClipTap,
                  showPlayButton: false,
                  showCameraIcon: false,
                  camera: camera,
                )
              : CameraTimelineEmptyCard(timeLabel: entry.timeLabel),
        ),
      ],
    );
  }
}

class CameraTimelineClipCard extends StatelessWidget {
  final CameraTimelineClip clip;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final bool showPlayButton;
  final bool showCameraIcon;
  final CameraEntry camera;

  // Cache accepted customer_id to avoid repeated async calls
  static String? _cachedAcceptedCustomerId;

  const CameraTimelineClipCard({
    super.key,
    required this.clip,
    required this.selected,
    this.onTap,
    this.onPlay,
    this.showPlayButton = true,
    this.showCameraIcon = true,
    required this.camera,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12, right: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.deepOrange : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacitySafe(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: SizedBox(
                  height: 96,
                  child: Builder(
                    builder: (context) {
                      // compute gradient/decoration once per card to avoid repeated allocations
                      final gradient = LinearGradient(
                        colors: [
                          clip.accent.withOpacitySafe(0.9),
                          clip.accent.withOpacitySafe(0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      );

                      final placeholder = Container(
                        decoration: BoxDecoration(gradient: gradient),
                      );

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (clip.thumbnailUrl != null &&
                              clip.thumbnailUrl!.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: clip.thumbnailUrl!,
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => placeholder,
                              errorWidget: (ctx, url, error) {
                                debugPrint(
                                  '⚠️ Thumbnail load failed for $url: $error',
                                );
                                return placeholder;
                              },
                            )
                          else
                            placeholder,

                          // small overlay icon in the bottom-right
                          if (showCameraIcon)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  top: 8,
                                  right: 8,
                                  bottom: 8,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacitySafe(0.35),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacitySafe(
                                          0.18,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.videocam,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxBtn = math.min(96.0, constraints.maxWidth * 0.28);
                    final compactLocal = constraints.maxWidth < 150.0;
                    final screenWidth = MediaQuery.of(context).size.width;
                    // global breakpoint: compact when the whole screen is narrow
                    final compactGlobal = screenWidth < 360.0;
                    final useCompact = compactLocal || compactGlobal;
                    return Row(
                      children: [
                        Flexible(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clip.timeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (showPlayButton)
                          // animated switch between pill and icon-only using global breakpoint
                          PlayActionButton(
                            key: ValueKey(useCompact ? 'icon_only' : 'pill'),
                            useCompact: useCompact,
                            maxWidth: maxBtn,
                            onPressed: onPlay ?? onTap,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) async {
    AppLogger.d('[Timeline] ========== _handleTap called ==========');
    AppLogger.d('[Timeline] Clicked clip.id=${clip.id}');
    AppLogger.d('[Timeline] Clicked clip.thumbnailUrl=${clip.thumbnailUrl}');

    onTap?.call();
    final meta = clip.metadata;
    if (meta != null && meta.isNotEmpty) {
      var event = _buildTimelineEventLog(clip, camera);

      AppLogger.d('[Timeline] Initial event imageUrls: ${event.imageUrls}');
      AppLogger.d(
        '[Timeline] event.eventId=${event.eventId}, clip.id=${clip.id}',
      );

      if (event.eventId == clip.id) {
        try {
          final resolver = EventsRemoteDataSource();
          final found = await resolver.listEvents(
            limit: 1,
            extraQuery: {'snapshot_id': clip.id},
          );
          if (found.isNotEmpty) {
            final resolved = EventLog.fromJson(found.first);

            final updatedDetectionData = Map<String, dynamic>.from(
              resolved.detectionData ?? {},
            );
            updatedDetectionData['snapshot_id'] = clip.id;

            AppLogger.d(
              '[Timeline] Overriding snapshot_id with clip.id=${clip.id} (was: ${resolved.detectionData?['snapshot_id']})',
            );

            event = EventLog(
              eventId: resolved.eventId,
              status: resolved.status,
              eventType: resolved.eventType,
              eventDescription: resolved.eventDescription,
              confidenceScore: resolved.confidenceScore,
              detectedAt: resolved.detectedAt,
              createdAt: resolved.createdAt,
              detectionData: updatedDetectionData,
              contextData: resolved.contextData,
              boundingBoxes: resolved.boundingBoxes,
              confirmStatus: resolved.confirmStatus,
              lifecycleState: resolved.lifecycleState,
              cameraId: resolved.cameraId,
              imageUrls: resolved.imageUrls,
              aiAnalysisResult: resolved.aiAnalysisResult,
              proposedStatus: resolved.proposedStatus,
              pendingUntil: resolved.pendingUntil,
            );

            AppLogger.d(
              '[Timeline] Snapshot lookup resolved eventId=${event.eventId} for snapshot=${clip.id}',
            );
            AppLogger.d(
              '[Timeline] Resolved event imageUrls: ${event.imageUrls}',
            );
            AppLogger.d(
              '[Timeline] Resolved event detectionData keys: ${event.detectionData?.keys}',
            );
          } else {
            AppLogger.w('[Timeline] No event found for snapshot_id=${clip.id}');
          }
        } catch (e) {
          AppLogger.e('[Timeline] Snapshot->event lookup failed: $e');
        }
      } else {
        AppLogger.d(
          '[Timeline] event.eventId already a real eventId, skipping API lookup',
        );
      }

      try {
        final updatedDetectionData = Map<String, dynamic>.from(
          event.detectionData ?? {},
        );
        updatedDetectionData['snapshot_id'] = clip.id;

        event = EventLog(
          eventId: event.eventId,
          status: event.status,
          eventType: event.eventType,
          eventDescription: event.eventDescription,
          confidenceScore: event.confidenceScore,
          detectedAt: event.detectedAt,
          createdAt: event.createdAt,
          detectionData: updatedDetectionData,
          contextData: event.contextData,
          boundingBoxes: event.boundingBoxes,
          confirmStatus: event.confirmStatus,
          lifecycleState: event.lifecycleState,
          cameraId: event.cameraId,
          imageUrls: event.imageUrls,
          aiAnalysisResult: event.aiAnalysisResult,
          proposedStatus: event.proposedStatus,
          pendingUntil: event.pendingUntil,
        );
        AppLogger.d('[Timeline] Enforced snapshot_id=${clip.id} on event');
      } catch (e) {
        AppLogger.w('[Timeline] Failed to enforce snapshot_id: $e');
      }

      AppLogger.d(
        '[Timeline] About to show images modal for event.eventId=${event.eventId}',
      );
      AppLogger.d(
        '[Timeline] Final event detectionData[snapshot_id]=${event.detectionData?['snapshot_id']}',
      );
      bool precomputedCanEdit = false;
      String? precomputedReason;
      try {
        final permProvider = Provider.of<PermissionsProvider>(
          context,
          listen: false,
        );
        String? customerId = event.contextData?['customer_id']?.toString();
        customerId ??= _cachedAcceptedCustomerId; // use cached if available

        if (customerId == null || customerId.isEmpty) {
          precomputedCanEdit = false;
          precomputedReason = 'Thiếu thông tin customer_id';
        } else {
          final hasPermission = permProvider.hasPermission(
            customerId,
            'alert_ack',
          );
          if (!hasPermission) {
            precomputedCanEdit = false;
            precomputedReason =
                'Bạn không có quyền đề xuất thay đổi sự kiện. Quyền "Thay đổi sự kiện" đã bị thu hồi.';
          } else {
            final ref = event.createdAt ?? event.detectedAt;
            if (ref != null &&
                DateTime.now().difference(ref) > const Duration(days: 2)) {
              precomputedCanEdit = false;
              precomputedReason =
                  'Sự kiện đã quá 2 ngày, không thể đề xuất thay đổi.';
            } else {
              final status = event.confirmationState?.toUpperCase();
              final canPropose =
                  status == 'DETECTED' || status == 'REJECTED_BY_CUSTOMER';
              if (!canPropose) {
                precomputedCanEdit = false;
                precomputedReason =
                    'Sự kiện đã được thay đổi trước đó hoặc đang chờ duyệt, không thể đề xuất lần nữa.';
              } else {
                precomputedCanEdit = true;
                precomputedReason = null;
              }
            }
          }
        }
      } catch (e) {
        AppLogger.e('[Timeline] Permission compute error: $e');
        precomputedCanEdit = false;
        precomputedReason = 'Lỗi kiểm tra quyền';
      }

      AppLogger.d(
        '[Timeline] ========== _handleTap about to call _showImagesModal ==========',
      );

      _showImagesModal(
        context,
        event,
        camera,
        snapshotId: clip.id,
        precomputedCanEdit: precomputedCanEdit,
        precomputedReason: precomputedReason,
      );
      return;
    }

    final url = clip.thumbnailUrl?.trim();
    if (url == null || url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).maybePop(),
        child: Dialog(
          backgroundColor: Colors.black.withOpacitySafe(0.85),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 48,
          ),
          child: Stack(
            children: [
              InteractiveViewer(
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (ctx, _) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (ctx, _, __) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showImagesModal(
    BuildContext pageContext,
    EventLog event,
    CameraEntry camera, {
    required String snapshotId,
    bool? precomputedCanEdit,
    String? precomputedReason,
  }) {
    return showDialog(
      context: pageContext,
      builder: (dialogCtx) {
        int? selectedIndex;

        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(pageContext).size.width * 0.9,
              height: MediaQuery.of(pageContext).size.height * 0.7,
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
                      const Expanded(
                        child: Text(
                          'Hình ảnh',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      // Edit button - use precomputed permission (aligned with ActionLogCardImages)
                      Builder(
                        builder: (ctx) {
                          final canEdit = precomputedCanEdit == true;
                          final tooltip = canEdit
                              ? 'Cập nhật sự kiện'
                              : (precomputedReason ?? 'Không đủ điều kiện');

                          return IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: tooltip,
                            onPressed: canEdit
                                ? () {
                                    try {
                                      Navigator.of(pageContext).pop();
                                    } catch (_) {}
                                    Navigator.push(
                                      pageContext,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProposeScreen(logEntry: event),
                                      ),
                                    );
                                  }
                                : null,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Image list (grid or list)
                  Expanded(
                    child: FutureBuilder<List<String>>(
                      key: ValueKey('images_' + snapshotId),
                      future: _loadImagesForClip(event, snapshotId),
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final urls = snapshot.data ?? [];

                        if (urls.isEmpty) {
                          return Center(
                            child: Text(
                              'Không có hình ảnh',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          );
                        }

                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: urls.length,
                          itemBuilder: (ctx, idx) {
                            return GestureDetector(
                              onTap: () => setDialogState(() {
                                selectedIndex = idx;
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedIndex == idx
                                        ? Colors.blue
                                        : Colors.grey.shade300,
                                    width: selectedIndex == idx ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: _buildImage(urls[idx]),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Đóng'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<EventEditValidation> _checkCanEditAsync(
    BuildContext context,
    EventLog event,
  ) async {
    try {
      final permProvider = Provider.of<PermissionsProvider>(
        context,
        listen: false,
      );

      // 1) From event context if available
      String? customerId = event.contextData?['customer_id']?.toString();

      // 2) Use cached accepted customer id if present
      customerId ??= _cachedAcceptedCustomerId;

      // 3) Fallback: fetch accepted assignments (await)
      if (customerId == null || customerId.isEmpty) {
        try {
          final assignmentsDs = AssignmentsRemoteDataSource();
          final list = await assignmentsDs.listPending(status: 'accepted');
          final active = list
              .where(
                (a) => a.isActive && (a.status.toLowerCase() == 'accepted'),
              )
              .toList();
          if (active.isNotEmpty) {
            customerId = active.first.customerId;
            _cachedAcceptedCustomerId = customerId;
          }
        } catch (e) {
          AppLogger.w('[Timeline] Failed to fetch accepted assignments: $e');
        }
      }

      if (customerId == null || customerId.isEmpty) {
        AppLogger.w(
          '[Timeline] Cannot edit: missing customer_id for event ${event.eventId}',
        );
        return EventEditValidation.denied('Thiếu thông tin customer_id');
      }

      return canEditEvent(
        event: event,
        permissionsProvider: permProvider,
        customerId: customerId,
      );
    } catch (e) {
      AppLogger.e('[Timeline] Failed to check edit permission: $e');
      return EventEditValidation.denied('Lỗi kiểm tra quyền');
    }
  }

  Future<List<String>> _loadEventImages(EventLog event) async {
    try {
      AppLogger.d('[Timeline] Loading images for eventId=${event.eventId}');
      AppLogger.d('[Timeline] Event imageUrls: ${event.imageUrls}');
      AppLogger.d('[Timeline] Event detectionData: ${event.detectionData}');

      final imageSources = await loadEventImageUrls(event);
      final urls = imageSources.map((src) => src.path).toList();

      AppLogger.d('[Timeline] Loaded ${urls.length} image URLs: $urls');
      return urls;
    } catch (e) {
      AppLogger.e('[Timeline] Failed to load event images: $e');
      return [];
    }
  }

  Future<List<String>> _loadImagesForEvent(EventLog event) async {
    try {
      AppLogger.d(
        '[Timeline] ========== _loadImagesForEvent called ==========',
      );
      AppLogger.d('[Timeline] Loading images for eventId=${event.eventId}');
      AppLogger.d('[Timeline] Event has imageUrls: ${event.imageUrls}');
      AppLogger.d('[Timeline] Event detectionData: ${event.detectionData}');
      AppLogger.d(
        '[Timeline] Event detectionData[snapshot_id]: ${event.detectionData?['snapshot_id']}',
      );

      final imageSources = await loadEventImageUrls(event);
      final urls = imageSources.map((src) => src.path).toList();

      AppLogger.d('[Timeline] Loaded ${urls.length} image URLs from snapshot');
      for (var i = 0; i < urls.length; i++) {
        AppLogger.d('[Timeline]   [$i]: ${urls[i]}');
      }

      return urls;
    } catch (e, st) {
      AppLogger.e('[Timeline] Failed to load event images: $e', e, st);
      return [];
    }
  }

  Future<List<String>> _loadImagesFromSnapshot(String snapshotId) async {
    try {
      AppLogger.d('[Timeline] Loading images for snapshot=$snapshotId');

      final resolver = EventsRemoteDataSource();
      final found = await resolver.listEvents(
        limit: 1,
        extraQuery: {'snapshot_id': snapshotId},
      );

      EventLog event;
      if (found.isNotEmpty) {
        final resolved = EventLog.fromJson(found.first);
        final updatedDetectionData = Map<String, dynamic>.from(
          resolved.detectionData ?? {},
        );
        updatedDetectionData['snapshot_id'] = snapshotId;

        event = EventLog(
          eventId: resolved.eventId,
          status: resolved.status,
          eventType: resolved.eventType,
          eventDescription: resolved.eventDescription,
          confidenceScore: resolved.confidenceScore,
          detectedAt: resolved.detectedAt,
          createdAt: resolved.createdAt,
          detectionData: updatedDetectionData,
          contextData: resolved.contextData,
          boundingBoxes: resolved.boundingBoxes,
          confirmStatus: resolved.confirmStatus,
          lifecycleState: resolved.lifecycleState,
          cameraId: resolved.cameraId,
          imageUrls: resolved.imageUrls,
          aiAnalysisResult: resolved.aiAnalysisResult,
          proposedStatus: resolved.proposedStatus,
          pendingUntil: resolved.pendingUntil,
        );
      } else {
        AppLogger.w(
          '[Timeline] No event found for snapshot_id=$snapshotId, using minimal event',
        );
        event = EventLog(
          eventId: snapshotId,
          status: 'unknown',
          eventType: 'unknown',
          confidenceScore: 0.0,
          confirmStatus: false,
          detectionData: {'snapshot_id': snapshotId},
        );
      }

      final imageSources = await loadEventImageUrls(event);
      final urls = imageSources.map((src) => src.path).toList();

      AppLogger.d(
        '[Timeline] Loaded ${urls.length} images for snapshot=$snapshotId',
      );
      for (var i = 0; i < urls.length; i++) {
        AppLogger.d('[Timeline]   [$i]: ${urls[i]}');
      }
      return urls;
    } catch (e, st) {
      AppLogger.e('[Timeline] Failed to load snapshot images: $e', e, st);
      return [];
    }
  }

  Future<List<String>> _loadImagesForClip(
    EventLog event,
    String snapshotId,
  ) async {
    final urls = await _loadImagesForEvent(event);
    if (urls.isNotEmpty) return urls;
    return _loadImagesFromSnapshot(snapshotId);
  }

  Widget _buildImage(String imagePath) {
    final isLocalFile = !imagePath.startsWith('http');

    if (isLocalFile) {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (c, e, st) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image),
        ),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        placeholder: (c, u) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image),
        ),
        errorWidget: (c, u, e) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image),
        ),
      );
    }
  }
}

/// Compact/reponsive play action used inside clip cards.
class PlayActionButton extends StatelessWidget {
  final bool useCompact;
  final double maxWidth;
  final VoidCallback? onPressed;

  const PlayActionButton({
    super.key,
    required this.useCompact,
    required this.maxWidth,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = Colors.orange.shade700;
    if (useCompact) {
      return SizedBox(
        width: 40,
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.orange.shade50,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.play_arrow, size: 18, color: Colors.orange),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: maxWidth,
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: accentColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Xem',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Removed per-card HEAD checks for performance; using CachedNetworkImage
// directly with placeholder/error fallback reduces extra network calls and
// simplifies behavior.

class CameraTimelineEmptyCard extends StatelessWidget {
  final String timeLabel;

  const CameraTimelineEmptyCard({super.key, required this.timeLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Icon(Icons.timelapse, color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khoảng trống $timeLabel',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Không có bản ghi trong khoảng thời gian này',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
