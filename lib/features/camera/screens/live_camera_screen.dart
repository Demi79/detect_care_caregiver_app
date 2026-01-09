import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/alarm/data/alarm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/alarm/data/alarm_status.dart';
import 'package:detect_care_caregiver_app/features/alarm/services/active_alarm_notifier.dart';
import 'package:detect_care_caregiver_app/features/alarm/services/alarm_status_service.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_core.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_player_factory.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_stream_helper.dart';
import 'package:detect_care_caregiver_app/features/camera/core/i_camera_player.dart';
import 'package:detect_care_caregiver_app/features/camera/core/rtsp_vlc_player.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/camera_timeline_screen.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_access_guard.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_screenshot_use_case.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/features_panel.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/status_chip.dart';
import 'package:detect_care_caregiver_app/features/emergency/emergency_call_helper.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:provider/provider.dart';
import 'package:detect_care_caregiver_app/core/providers/permissions_provider.dart';
import 'package:detect_care_caregiver_app/features/shared_permissions/screens/caregiver_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Màn hình camera chính với kiến trúc module hóa
class LiveCameraScreen extends StatefulWidget {
  final String? initialUrl;
  final bool loadCache;
  final CameraEntry? camera;
  final String? mappedEventId;
  final String? customerId;

  const LiveCameraScreen({
    super.key,
    this.initialUrl,
    this.loadCache = true,
    this.camera,
    this.mappedEventId,
    this.customerId,
  });

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen>
    with WidgetsBindingObserver {
  late final CameraStateManager _stateManager;
  late final CameraService _cameraService;
  late final CameraAccessGuard _accessGuard;
  ICameraPlayer? _currentPlayer;
  bool _prevIsFullscreen = false;
  bool _handlingFullscreen = false;
  Timer? _startDebounce;
  bool _streamDisposed = false;
  bool _stateDisposed = false;
  bool _alarming = false;
  bool _emergencyCalling = false;
  bool _cancelingAlarm = false;
  bool _activatingAlarm = false;
  late final CameraScreenshotUseCase _screenshotUseCase;

  @override
  @override
  void initState() {
    super.initState();
    // Thêm observer để monitor lifecycle
    WidgetsBinding.instance.addObserver(this);

    AlarmStatusService.instance.startPolling(
      interval: const Duration(seconds: 10),
    );

    // Lightweight init - chỉ setup state managers (không load/play)
    final shouldLoadCache = widget.initialUrl == null && widget.loadCache;
    _stateManager = CameraStateManager(loadCache: shouldLoadCache);
    _cameraService = cameraService;
    _screenshotUseCase = CameraScreenshotUseCase(
      ApiClient(tokenProvider: AuthStorage.getAccessToken),
    );
    _accessGuard = CameraAccessGuard();

    // Defer heavy initialization đến sau khi UI hiển thị
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHeavyResources();
    });
  }

  /// Khởi tạo các resource nặng sau khi UI đã render
  Future<void> _initializeHeavyResources() async {
    try {
      // Load configuration từ cache (non-async)
      _stateManager.init();

      // Set initial URL nếu có
      if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
        _stateManager.urlController.text = widget.initialUrl!;
        _stateManager.setCurrentUrl(widget.initialUrl!);
      }

      // Defer camera playback đến microtask untuk không block UI
      Future.microtask(() async {
        try {
          if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
            await _startPlay();
          }
        } catch (e) {
          AppLogger.w('⚠️ [Camera] Auto-play failed: $e');
        }
      });
    } catch (e) {
      AppLogger.e('❌ [Camera] Heavy init failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.d('🔄 [Camera] App lifecycle: $state');

    switch (state) {
      case AppLifecycleState.paused:
        // App moved to background
        AppLogger.d('⏸️ [Camera] App paused - stream may buffer');
        break;

      case AppLifecycleState.resumed:
        // App back to foreground - check stream health
        AppLogger.d('▶️ [Camera] App resumed - checking stream...');
        _onAppResumed();
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        AppLogger.d('🛑 [Camera] App lifecycle change: $state');
        break;
    }
  }

  /// Handle app resume - verify stream is still playing
  Future<void> _onAppResumed() async {
    try {
      final player = _currentPlayer;
      if (player == null) {
        AppLogger.w('⚠️ [Camera] No player on resume - restarting...');
        await _startPlay();
        return;
      }

      // Give stream time to stabilize after app resume
      AppLogger.i(
        '[Camera] Stream still active (${player.protocol}), continuing...',
      );
      await Future.delayed(const Duration(milliseconds: 800));

      // Stream is active, no need to reload
      AppLogger.i('✅ [Camera] Stream still active after resume');
    } catch (e, st) {
      AppLogger.w('⚠️ [Camera] Error on resume: $e', e, st);
    }
  }

  Future<void> _disposeStreamResources() async {
    if (_streamDisposed) return;
    _streamDisposed = true;

    // Huỷ các tác vụ đang chờ trước khi dọn dẹp
    _startDebounce?.cancel();
    _startDebounce = null;

    // Huỷ dịch vụ camera (điều này sẽ dispose controller nếu có)
    await _cameraService.dispose();

    // Clear controller reference held by state manager
    _stateManager.clearController();
  }

  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    // Dispose current player
    unawaited(_currentPlayer?.dispose());
    _currentPlayer = null;

    unawaited(_disposeStreamResources());

    if (!_stateDisposed) {
      _stateManager.dispose();
      _stateDisposed = true;
    }

    _stateManager.urlController.dispose();
    super.dispose();
  }

  Future<void> _ensurePlaybackOnFullscreen() async {
    if (_handlingFullscreen) return;
    _handlingFullscreen = true;
    try {
      // UX-optimized strategy: try to warm/ensure the controller first
      // (fast path). If warming doesn't reach playing state within a
      // short timeout, fall back to a full recreate (safe path).
      var url = _stateManager.urlController.text.trim();
      if (url.isEmpty) url = _stateManager.currentUrl ?? '';
      if (url.isEmpty) return;

      AppLogger.d('🐛 [Camera] fullscreen warm-then-fallback url=$url');

      // Indicate transient work to the UI (small spinner overlay)
      _stateManager.setStarting(true);

      // Check current player state first
      final currentPlayer = _currentPlayer;
      if (currentPlayer != null) {
        AppLogger.d('✅ [Camera] Stream already playing on fullscreen');
        _stateManager.setStarting(false);
        return;
      }

      // Try to start playback for the URL
      await _startPlay();
      _stateManager.setStarting(false);
    } finally {
      _handlingFullscreen = false;
    }
  }

  Future<void> _openTimeline() async {
    final camera = widget.camera;
    if (camera == null) {
      if (mounted) {
        context.showCameraMessage(
          'Không tìm thấy thông tin camera để mở timeline.',
        );
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CameraTimelineScreen(camera: camera),
        settings: const RouteSettings(name: 'camera_timeline_screen'),
      ),
    );
  }

  Future<void> _startPlay() async {
    // Đảm bảo người dùng có quyền (gói) trước khi thử phát
    final allowed = await _accessGuard.ensureSubscriptionAllowed(context);
    if (!allowed) return;

    final url = _stateManager.urlController.text.trim();
    if (url.isEmpty) return;

    if (_stateManager.isStarting) {
      return; // debounce
    }
    if (_stateManager.currentUrl == url && _currentPlayer != null) {
      return;
    }

    _stateManager.setStarting(true);
    _stateManager.setStatusMessage(
      _stateManager.isHd
          ? CameraConstants.connectingHdMessage
          : CameraConstants.connectingMessage,
    );
    _stateManager.setCurrentUrl(url);

    await _stateManager.saveUrl(url);

    try {
      AppLogger.i(
        '🔗 [Camera] Starting playback for url=$url (protocol: ${CameraPlayerFactory.detectProtocol(url)})',
      );

      // Dispose old player
      await _currentPlayer?.dispose();
      _currentPlayer = null;

      // Play with new architecture - supports automatic fallback
      _currentPlayer = await CameraStreamHelper.playWithFallback(
        initialUrl: url,
        camera: widget.camera,
        maxRetries: 1,
        initTimeout: const Duration(seconds: 3),
      );

      if (!mounted) return;

      if (_currentPlayer != null) {
        // Phát thành công - tối ưu UX
        _stateManager.showControlsTemporarily();
        _stateManager.setStatusMessage(null);
        _stateManager.setStarting(false);

        // Haptic feedback để người dùng biết đã kết nối
        HapticFeedback.lightImpact();

        AppLogger.i(
          '✅ [Camera] Stream started successfully with ${_currentPlayer!.protocol} (${_currentPlayer!.streamUrl})',
        );

        // Trigger rebuild to show new player widget
        if (mounted) setState(() {});
        return;
      }

      // All attempts failed
      _stateManager.setStatusMessage(CameraConstants.cannotPlayMessage);
      AppLogger.e(
        '❌ [Camera] All stream attempts failed. Available protocols: ${CameraStreamHelper.getProtocolPriority(widget.camera).join(", ")}',
      );
    } catch (e, st) {
      AppLogger.e('❌ [Camera] Stream play error: $e', e, st);
      if (mounted) {
        _stateManager.setStatusMessage(CameraConstants.cannotPlayMessage);
        context.showCameraMessage(CameraConstants.checkUrlMessage);
      }
    }

    _stateManager.setStarting(false);
  }

  String? _extractCameraIdFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final q = uri.queryParameters['camera'] ?? uri.queryParameters['cam'];
        if (q != null && q.isNotEmpty) return q;
        final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
        if (seg != null && seg.isNotEmpty) return seg;
      }
    } catch (_) {}
    final m1 = RegExp(r'camera=([A-Za-z0-9\-_.]+)').firstMatch(url);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r'/camera/([A-Za-z0-9\-_.]+)').firstMatch(url);
    if (m2 != null) return m2.group(1);
    return null;
  }

  Future<void> _changeFps(int newFps) async {
    if (_stateManager.isStarting) return;

    final fps = newFps.clampFps();
    final url = _stateManager.urlController.text.trim();
    if (url.isEmpty) return;

    final newUrl = CameraHelpers.withFps(url, fps);
    _stateManager.updateSettings(fps: fps);
    _stateManager.urlController.text = newUrl;

    if (newUrl != _stateManager.currentUrl) {
      await _startPlay();
    }
  }

  Future<void> _changeRetentionDays(int days) async {
    _stateManager.updateSettings(retentionDays: days.clampRetentionDays());
  }

  Future<void> _changeChannels(Set<String> channels) async {
    _stateManager.updateSettings(channels: channels);

    setState(() => _alarming = true);
    String? snapshotPath;
    bool createdOk = false;
    try {
      AppLogger.d(
        '[Camera] Attempting to take snapshot for alarm (currentUrl=${_stateManager.currentUrl})',
      );
      snapshotPath = await _currentPlayer?.takeSnapshot();
      AppLogger.d('[Camera] player.takeSnapshot returned: $snapshotPath');
      if (snapshotPath == null) {
        AppLogger.d('[Camera] falling back to cameraService.takeSnapshot()');
        snapshotPath = await _cameraService.takeSnapshot();
        AppLogger.d(
          '[Camera] cameraService.takeSnapshot returned: $snapshotPath',
        );
      }

      final extracted = _extractCameraIdFromUrl(
        _stateManager.currentUrl ?? _stateManager.urlController.text,
      );
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\u0000'
            .replaceAll('\u0000', ''),
      );
      final cameraId = (extracted != null && uuidRegex.hasMatch(extracted))
          ? extracted
          : '0fd3f12d-ef70-4d41-a622-79fa5db67a49';

      if (widget.mappedEventId != null && widget.mappedEventId!.isNotEmpty) {
        final eventId = widget.mappedEventId!;
        try {
          await EventsRemoteDataSource().updateEventLifecycle(
            eventId: eventId,
            lifecycleState: 'ALARM_ACTIVATED',
            notes: 'Kích hoạt từ giao diện camera trực tiếp',
          );

          // Try to notify external alarm control as well.
          try {
            final userId = await AuthStorage.getUserId();
            if (userId != null && userId.isNotEmpty) {
              await AlarmRemoteDataSource().setAlarm(
                eventId: eventId,
                userId: userId,
                cameraId: cameraId,
                enabled: true,
              );
            }
          } catch (e) {
            AppLogger.e('External alarm call failed for mapped event: $e');
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kích hoạt báo động cho sự kiện.')),
            );
            ActiveAlarmNotifier.instance.update(true);
          }
        } catch (e, st) {
          AppLogger.e('Failed to activate mapped event alarm: $e', e, st);
          if (mounted) {
            context.showCameraMessage('Kích hoạt báo động thất bại.');
          }
        }
      } else {
        // Check if snapshot was captured successfully
        snapshotPath = snapshotPath ?? '';
        EventLog? createdEvent;
        try {
          final svc = EventService.withDefaultClient();
          createdEvent = await svc.sendManualAlarm(
            cameraId: cameraId,
            snapshotPath: snapshotPath,
            cameraName: widget.camera?.name ?? 'Camera',
            streamUrl: _stateManager.currentUrl,
          );
          createdOk = true;
        } catch (e, st) {
          AppLogger.e('❌ [Camera] sendManualAlarm failed', e, st);
          if (mounted) context.showCameraMessage('Gửi báo động thất bại.');
          return;
        }

        try {
          final userId = await AuthStorage.getUserId();
          if (userId != null && userId.isNotEmpty) {
            try {
              await AlarmRemoteDataSource().setAlarm(
                eventId: createdEvent!.eventId,
                userId: userId,
                cameraId: cameraId,
                enabled: true,
              );
            } catch (e) {
              AppLogger.e('External alarm call failed from camera overlay: $e');
            }
          } else {
            AppLogger.d('Cannot call external alarm: userId not available');
          }
        } catch (e) {
          AppLogger.e('Failed to resolve userId for external alarm: $e');
        }

        if (!mounted) return;
        if (createdOk) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gửi báo động thành công.')),
          );
        }
        ActiveAlarmNotifier.instance.update(true);
      }
    } catch (e, st) {
      AppLogger.e('❌ [Camera] send manual alarm flow error', e, st);
      if (!createdOk && mounted) {
        context.showCameraMessage('Gửi báo động thất bại.');
      }
    } finally {
      if (mounted) setState(() => _alarming = false);
    }
  }

  Future<void> _reloadStream() async {
    try {
      // Check if already reloading
      if (_stateManager.isStarting) {
        AppLogger.d('⏳ [Camera] Already reloading, skipping...');
        return;
      }

      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Show loading state
      _stateManager.setStarting(true);
      _stateManager.setStatusMessage('Đang tải lại...');

      AppLogger.i('🔄 [Camera] Reloading stream...');

      // Cleanup và đợi để đảm bảo resources được giải phóng
      await _disposeStreamResources();
      await Future.delayed(const Duration(milliseconds: 300));

      // Restart stream
      await _startPlay();

      AppLogger.i('✅ [Camera] Stream reloaded successfully');
    } catch (e, st) {
      AppLogger.e('❌ [Camera] Failed to reload stream', e, st);
      if (mounted) {
        _stateManager.setStatusMessage('Không thể tải lại');
        _stateManager.setStarting(false);
        context.showCameraMessage('Lỗi khi tải lại camera. Vui lòng thử lại.');
      }
    }
  }

  Future<void> _onCaptureManualEvent() async {
    if (_alarming) return;
    setState(() => _alarming = true);

    try {
      // 1️⃣ Capture snapshot
      String? snapshotPath;
      try {
        snapshotPath = await _captureCurrentSnapshot();
      } catch (e) {
        AppLogger.w('[Camera] Snapshot capture failed: $e');
      }

      if (snapshotPath == null || snapshotPath.isEmpty) {
        if (mounted) {
          context.showCameraMessage('Không thể chụp ảnh. Vui lòng thử lại.');
        }
        return;
      }

      // 2️⃣ Create manual event
      // This automatically:
      // - Creates event on server (with create_by set)
      // - Fetches fresh event via REST to validate
      // - In-app popup will be suppressed by create_by self-check
      final svc = EventService.withDefaultClient();
      final createdEvent = await svc.sendManualAlarm(
        cameraId: widget.camera?.id ?? '',
        snapshotPath: snapshotPath,
        cameraName: widget.camera?.name,
        streamUrl: _stateManager.currentUrl,
      );

      AppLogger.i(
        '✅ [Camera] Manual event created eventId=${createdEvent.eventId}',
      );

      if (!mounted) return;

      // 3️⃣ Show success — no external alarm activation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã ghi nhận báo động thủ công.')),
      );
    } catch (e, st) {
      AppLogger.e('❌ [Camera] Manual event creation failed', e, st);
      if (mounted) {
        context.showCameraMessage('Không thể ghi nhận báo động.');
      }
    } finally {
      if (mounted) {
        setState(() => _alarming = false);
      }
    }
  }

  Future<String?> _captureCurrentSnapshot() async {
    // 1. Try RTSP snapshot (nếu có)
    final controller = _currentPlayer is RtspVlcPlayer
        ? (_currentPlayer as RtspVlcPlayer).controller
        : null;

    final localPath = await _cameraService.takeSnapshot(controller: controller);
    if (localPath != null) return localPath;

    // 2. Remote screenshot fallback
    final cameraId = widget.camera?.id ?? '';
    if (cameraId.isEmpty) {
      AppLogger.d('[Camera] cameraId empty, cannot fallback');
      return null;
    }

    final imageUrl = await _screenshotUseCase.captureScreenshotWithFallback(
      cameraId: cameraId,
      fallbackImageUrl: widget.camera?.thumb,
    );

    if (imageUrl == null) {
      AppLogger.d('[Camera] Remote screenshot returned null');
      return null;
    }

    // 3. Download image về local
    return _downloadImageToLocalFile(imageUrl, cameraId);
  }

  // Future<void> _toggleMute() async {
  //   await _cameraService.toggleMute(_stateManager.isMuted);
  // }

  // void _toggleInfrared() {
  //   setState(() => _infraredEnabled = !_infraredEnabled);
  //   if (!mounted) return;
  //   context.showCameraMessage(
  //     _infraredEnabled ? 'Đã bật hồng ngoại.' : 'Đã tắt hồng ngoại.',
  //   );
  // }

  Future<void> _handleEmergencyCall() async {
    if (_emergencyCalling) return;
    setState(() => _emergencyCalling = true);
    try {
      await EmergencyCallHelper.initiateEmergencyCall(context);
    } catch (e, st) {
      AppLogger.e('[Camera] emergency call failed', e, st);
      if (mounted) context.showCameraMessage('Không thể thực hiện cuộc gọi.');
    } finally {
      if (mounted) setState(() => _emergencyCalling = false);
    }
  }

  // Future<String> _chooseEmergencyPhone() async {
  //   String phone = '115';
  //   try {
  //     final userId = await AuthStorage.getUserId();
  //     if (userId != null && userId.isNotEmpty) {
  //       final list = await EmergencyContactsRemoteDataSource().list(userId);
  //       if (list.isNotEmpty) {
  //         list.sort((a, b) => b.alertLevel.compareTo(a.alertLevel));
  //         EmergencyContactDto? chosen;
  //         for (final c in list) {
  //           if (c.phone.trim().isNotEmpty) {
  //             chosen = c;
  //             break;
  //           }
  //         }
  //         chosen ??= list.first;
  //         if (chosen.phone.trim().isNotEmpty) {
  //           phone = chosen.phone.trim();
  //         }
  //       }
  //     }
  //   } catch (_) {}
  //   return phone.isEmpty ? '115' : phone;
  // }

  Future<void> _onCancelAlarm() async {
    final eventId = widget.mappedEventId;
    AppLogger.d(
      '[Camera] _onCancelAlarm called with eventId=$eventId, alarmActive=${ActiveAlarmNotifier.instance.value}',
    );
    if (_cancelingAlarm) return;
    setState(() => _cancelingAlarm = true);
    try {
      final status = await AlarmStatusService.instance.refreshStatus();
      final alarmActive = _computeAlarmActive(status);
      final activeIds = status?.activeAlarms ?? const <String>[];

      AppLogger.d(
        '[Camera] _onCancelAlarm: alarmActive=$alarmActive, isPlaying=${status?.isPlaying}, eventId=$eventId, activeIds=$activeIds',
      );

      if (!alarmActive) {
        AppLogger.d('[Camera] No active alarm from status API');
        if (mounted) {
          context.showCameraMessage('Không có báo động đang hoạt động.');
        }
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Đang hủy báo động...')),
      );

      final userId = await AuthStorage.getUserId();
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          context.showCameraMessage('Không xác thực được người dùng.');
        }
        return;
      }

      // If we have a mapped event id, mark that event as RESOLVED (don't
      // permanently cancel it) so the UI and audits reflect an acknowledged
      // alarm. Also attempt to notify external alarm controller.
      if (eventId != null && eventId.isNotEmpty) {
        AppLogger.d('[Camera] Canceling alarm for mapped event: $eventId');
        try {
          await EventsRemoteDataSource().updateEventLifecycle(
            eventId: eventId,
            lifecycleState: 'RESOLVED',
            notes: 'RESOLVED via camera overlay',
          );
        } catch (e) {
          AppLogger.e('Failed to resolve mapped event $eventId: $e');
        }

        try {
          await AlarmRemoteDataSource().cancelAlarm(
            eventId: eventId,
            userId: userId,
            cameraId: null,
          );
        } catch (e) {
          AppLogger.e('External cancel alarm failed: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã hủy báo động.')));
        }
        await AlarmStatusService.instance.refreshStatus();
        try {
          AppEvents.instance.notifyTableChanged('event_detections');
        } catch (_) {}
        return;
      }

      final idsToResolve = <String>{};

      if (activeIds.isNotEmpty) {
        idsToResolve.addAll(activeIds);
      }

      final statusEventId = status?.eventId;
      if (statusEventId != null && statusEventId.isNotEmpty) {
        idsToResolve.add(statusEventId);
      }

      if (idsToResolve.isEmpty) {
        final fallbackIds = await _fetchFallbackAlarmIds();
        idsToResolve.addAll(fallbackIds);
      }

      final ids = idsToResolve.toList();

      if (ids.isEmpty) {
        AppLogger.d('[Camera] No active alarm events found to cancel');
        if (mounted) {
          context.showCameraMessage('Không tìm thấy báo động đang hoạt động.');
        }
        try {
          AppEvents.instance.notifyTableChanged('event_detections');
        } catch (_) {}
        return;
      }

      for (final id in ids) {
        try {
          await EventsRemoteDataSource().updateEventLifecycle(
            eventId: id,
            lifecycleState: 'RESOLVED',
            notes: 'RESOLVED via camera overlay',
          );
        } catch (e) {
          AppLogger.e('Failed to resolve event $id: $e');
        }

        try {
          await AlarmRemoteDataSource().cancelAlarm(
            eventId: id,
            userId: userId,
            cameraId: null,
          );
        } catch (e) {
          AppLogger.e('External cancel alarm failed for $id: $e');
        }
      }

      AppLogger.d('[Camera] Resolved ${ids.length} alarm events: $ids');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã hủy báo động.')));
      await AlarmStatusService.instance.refreshStatus();
      try {
        AppEvents.instance.notifyTableChanged('event_detections');
      } catch (_) {}
    } catch (e, st) {
      AppLogger.e('Failed to cancel mapped event alarm: $e', e, st);
      if (mounted) context.showCameraMessage('Hủy báo động thất bại.');
    } finally {
      if (mounted) setState(() => _cancelingAlarm = false);
    }
  }

  Future<List<String>> _fetchFallbackAlarmIds() async {
    try {
      final to = DateTime.now().toUtc();
      final from = to.subtract(const Duration(minutes: 30));
      final params = <String, dynamic>{
        'lifecycle_state': 'ALARM_ACTIVATED',
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        'limit': 20,
      };
      final rows = await EventsRemoteDataSource().listEvents(
        extraQuery: params,
      );
      final ids = rows
          .map((r) => (r['id'] ?? r['event_id'] ?? r['eventId'])?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      return ids;
    } catch (e, st) {
      AppLogger.e('Failed to fetch fallback alarm ids: $e', e, st);
      return [];
    }
  }

  Future<void> _onActivateAlarm() async {
    final eventId = widget.mappedEventId;
    AppLogger.d('[Camera] _onActivateAlarm: eventId=$eventId');
    if (eventId == null || eventId.isEmpty) {
      AppLogger.w('[Camera] _onActivateAlarm: eventId is null or empty');
      return;
    }
    if (_activatingAlarm) return;
    setState(() => _activatingAlarm = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Đang kích hoạt báo động...')),
      );

      final userId = await AuthStorage.getUserId();
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          context.showCameraMessage('Không xác thực được người dùng.');
        }
        return;
      }

      AppLogger.d(
        '[Camera] Calling setAlarm: eventId=$eventId, userId=$userId',
      );
      await AlarmRemoteDataSource().setAlarm(
        eventId: eventId,
        userId: userId,
        cameraId: null,
        enabled: true,
      );
      AppLogger.d('[Camera] setAlarm completed successfully');

      await AlarmStatusService.instance.refreshStatus();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã kích hoạt báo động.')));
      }
    } catch (e, st) {
      AppLogger.e('Failed to activate alarm: $e', e, st);
      if (mounted) context.showCameraMessage('Kích hoạt báo động thất bại.');
    } finally {
      if (mounted) setState(() => _activatingAlarm = false);
    }
  }

  bool _computeAlarmActive(AlarmStatus? status) {
    final statusActive =
        status?.isEventActive(widget.mappedEventId) ??
        (status?.isPlaying ?? false);
    return statusActive || ActiveAlarmNotifier.instance.value;
  }

  @override
  Widget build(BuildContext context) {
    // Check stream_view permission using customerId or camera.userId
    bool hasStreamPermission = true;
    String? customerIdToCheck = widget.customerId ?? widget.camera?.userId;

    if (customerIdToCheck != null && customerIdToCheck.isNotEmpty) {
      try {
        final prov = context.watch<PermissionsProvider>();
        hasStreamPermission = prov.hasPermission(
          customerIdToCheck,
          'stream_view',
        );
        AppLogger.d(
          '[LiveCameraScreen] Permission check: customerId=$customerIdToCheck, hasStreamPermission=$hasStreamPermission',
        );
      } catch (e) {
        AppLogger.w('[LiveCameraScreen] Permission check error: $e');
        hasStreamPermission = true; // fallback to allow if provider fails
      }
    }

    if (!hasStreamPermission) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.1),
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFF374151),
                size: 18,
              ),
            ),
          ),
          title: const Text(
            'Camera trực tiếp',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 16),
                Text(
                  'Không có quyền truy cập',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn chưa được chia sẻ quyền xem camera trực tiếp. Hãy nhờ bệnh nhân cấp quyền truy cập trong "Quyền được chia sẻ".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CaregiverSettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.key),
                      label: const Text('Yêu cầu quyền'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_stateManager.isFullscreen) {
          _stateManager.toggleFullscreen();
          return;
        }

        // Take snapshot before disposing resources
        String? snapshotPath;
        try {
          AppLogger.d(
            '[Camera] onPop: attempting snapshot before pop (currentUrl=${_stateManager.currentUrl})',
          );
          AppLogger.d(
            '[Camera] onPop currentPlayer=${_currentPlayer != null ? _currentPlayer.runtimeType : 'null'}, protocol=${_currentPlayer?.protocol}',
          );
          snapshotPath = await _currentPlayer?.takeSnapshot();
          AppLogger.d(
            '[Camera] onPop player.takeSnapshot result: $snapshotPath',
          );
          if (snapshotPath == null) {
            AppLogger.d(
              '[Camera] onPop falling back to cameraService.takeSnapshot()',
            );
            snapshotPath = await _cameraService.takeSnapshot();
            AppLogger.d(
              '[Camera] onPop cameraService.takeSnapshot result: $snapshotPath',
            );
          }
        } catch (e, st) {
          AppLogger.e('[Camera] onPop snapshot error: $e', e, st);
        }

        if (snapshotPath != null && context.mounted) {
          Navigator.of(context).pop(snapshotPath);
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: StreamBuilder<CameraState>(
        stream: _stateManager.stateStream,
        initialData: _stateManager.state,
        builder: (context, snapshot) {
          // Handle case where stream might be closed during disposal
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.done) {
            return const SizedBox.shrink();
          }
          // Prevent rebuilding if state manager is disposed
          if (_stateManager.isDisposed) {
            return const SizedBox.shrink();
          }
          final state = snapshot.data ?? _stateManager.state;
          // Phát hiện chuyển trạng thái fullscreen và cố gắng đảm bảo
          // playback khi vào chế độ toàn màn hình. Dùng post-frame
          // callback để tránh side-effect trong quá trình build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (state.isFullscreen != _prevIsFullscreen) {
              _prevIsFullscreen = state.isFullscreen;
              if (state.isFullscreen) {
                _ensurePlaybackOnFullscreen();
              }
            }
          });
          return Scaffold(
            backgroundColor: Colors.white,
            // Khi chuyển sang chế độ fullscreen chúng ta ẩn AppBar của
            // màn hình chính để video có thể chiếm toàn bộ không gian
            // hiển thị còn lại. Việc này giúp tránh hiện tượng UI chrome
            // (AppBar) chồng lên vùng phát video khi người dùng xoay
            // màn hình hoặc khi overlay chiếm một phần không gian.
            // Nếu muốn trải nghiệm "immersive" thực thụ (ẩn cả status
            // bar / navigation bar của hệ thống) thì cần gọi SystemChrome
            // nhưng ở đây ta chỉ ẩn AppBar của ứng dụng để an toàn hơn.
            appBar: state.isFullscreen
                ? null
                : CameraWidgets.buildAppBar(
                    context: context,
                    onFullscreenToggle: _stateManager.toggleFullscreen,
                    isFullscreen: state.isFullscreen,
                  ),
            body: _buildBody(state),
          );
        },
      ),
    );
  }

  Widget _buildBody(CameraState state) {
    if (state.isFullscreen) {
      return CameraWidgets.buildFullscreenContainer(
        // Nếu chưa có player (placeholder), để null để cho inner
        // GestureDetector (nhấn để bắt phát) nhận sự kiện.
        onTap: _currentPlayer != null
            ? _stateManager.showControlsTemporarily
            : null,
        onDoubleTap: _stateManager.toggleFullscreen,
        child: _buildVideoStack(state),
      );
    }

    return SafeArea(
      bottom: true,
      top: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _buildCameraCard(state),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CameraFeaturesPanel(
                fps: state.settings.fps,
                onFpsChanged: _changeFps,
                retentionDays: state.settings.retentionDays,
                onRetentionChanged: _changeRetentionDays,
                channels: state.settings.channels,
                onChannelsChanged: _changeChannels,
                showRetention: false,
                timelineContentBuilder: (ctx) => _buildEmbeddedTimeline(ctx),
                onOpenTimeline: widget.camera != null
                    ? () => _openTimeline()
                    : null,
                camera: widget.camera,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildEmbeddedTimeline(BuildContext context) {
    final camera = widget.camera;
    if (camera == null) return null;

    final size = MediaQuery.sizeOf(context);
    final baseHeight = size.height.isFinite ? size.height * 0.55 : 520.0;
    final height = baseHeight.clamp(360.0, 640.0);

    return SizedBox(
      height: height,
      child: CameraTimelineScreen(
        camera: camera,
        embedded: true,
        loadFromApi: true,
      ),
    );
  }

  Widget _buildCameraCard(CameraState state) {
    final cameraName = widget.camera?.name ?? 'Camera trực tiếp';
    final isOnline = _currentPlayer != null && !state.initLoading;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCameraHeader(cameraName, isOnline),
          _buildCameraVideoSection(state),
          _buildInlineActionPanel(state),
        ],
      ),
    );
  }

  Widget _buildCameraHeader(String cameraName, bool isOnline) {
    final statusColor = isOnline
        ? const Color(0xFF22C55E)
        : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  cameraName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraVideoSection(CameraState state) {
    final hasPlayer = _currentPlayer != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: Colors.black,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _stateManager.toggleFullscreen,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPlayer)
                    _currentPlayer!.buildView()
                  else
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _startPlay();
                      },
                      child: CameraWidgets.buildPlaceholder(),
                    ),
                  if (state.statusMessage != null)
                    (() {
                      final msg = state.statusMessage!.toLowerCase();
                      final transient =
                          msg.contains('đang kết nối') ||
                          msg.contains('connecting') ||
                          msg.contains('đang phát') ||
                          msg.contains('playing');
                      if (transient) return const SizedBox.shrink();
                      return CameraStatusChip(text: state.statusMessage!);
                    })(),
                  // Positioned(
                  //   top: 12,
                  //   right: 12,
                  //   child: QualityBadge(isHd: state.isHd, onTap: _toggleQuality),
                  // ),
                  if (state.isStarting)
                    Container(
                      color: Colors.black38,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: _buildLiveBadge(state),
                  ),
                  _buildVideoIconOverlay(state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoIconOverlay(CameraState state) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: SafeArea(
        top: false,
        bottom: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: _buildCornerIconButtons(state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCornerIconButtons(CameraState state) {
    return Row(
      children: [
        _buildIconButton(
          icon: state.isFullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          tooltip: state.isFullscreen ? 'Thoát toàn màn hình' : 'Toàn màn hình',
          onTap: _stateManager.toggleFullscreen,
        ),
        const SizedBox(width: 8),
        _buildIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Tải lại luồng',
          onTap: () => unawaited(_reloadStream()),
        ),
      ],
    );
  }

  Widget _buildLiveBadge(CameraState state) {
    // final resolution = state.isHd ? '1080p' : '720p';
    // final fps = '${state.settings.fps}fps';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildLiveStatusRow(CameraState state) {
  //   final resolution = state.isHd ? '1080p' : '720p';
  //   final fps = '${state.settings.fps}fps';
  //   return Padding(
  //     padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
  //     child: Row(
  //       children: [
  //         Text(
  //           '$resolution • $fps',
  //           style: TextStyle(
  //             fontSize: 12,
  //             color: Colors.grey[700],
  //             letterSpacing: 0.2,
  //           ),
  //         ),
  //         const Spacer(),
  //         IconButton(
  //           padding: const EdgeInsets.all(6),
  //           constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
  //           iconSize: 20,
  //           icon: Icon(state.isMuted ? Icons.volume_off : Icons.volume_up),
  //           color: const Color(0xFF0F172A),
  //           tooltip: state.isMuted ? 'Mở tiếng' : 'Tắt tiếng',
  //           onPressed: _toggleMute,
  //         ),
  //         IconButton(
  //           padding: const EdgeInsets.all(6),
  //           constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
  //           iconSize: 20,
  //           icon: Icon(
  //             _infraredEnabled ? Icons.light_mode : Icons.light_mode_outlined,
  //           ),
  //           color: const Color(0xFF0F172A),
  //           tooltip: _infraredEnabled ? 'Tắt hồng ngoại' : 'Bật hồng ngoại',
  //           onPressed: _toggleInfrared,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildCameraActionOverlay(
    CameraState state, {
    bool fullscreen = false,
  }) {
    final horizontalPadding = fullscreen ? 8.0 : 12.0;
    final verticalPadding = fullscreen ? 10.0 : 14.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          bottom: verticalPadding,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: _buildActionPanelBackground(
              child: fullscreen
                  ? _buildFullscreenActionRow(state)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionIconRow(state, fullscreen),
                        const SizedBox(height: 12),
                        _buildActionPanelButtons(state, iconOnly: fullscreen),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenActionRow(CameraState state) {
    return ValueListenableBuilder<bool>(
      valueListenable: ActiveAlarmNotifier.instance,
      builder: (context, _, __) {
        final status = AlarmStatusService.instance.statusNotifier.value;
        final alarmActive = _computeAlarmActive(status);
        final mainLabel = alarmActive
            ? (_cancelingAlarm ? 'Đang hủy...' : 'Hủy báo động')
            : (_alarming ? 'Đang...' : 'Báo động');
        final mainIcon = alarmActive
            ? Icons.close_rounded
            : Icons.warning_amber_rounded;
        final onMainTap = alarmActive ? _onCancelAlarm : _onCaptureManualEvent;
        final mainLoading = alarmActive ? _cancelingAlarm : _alarming;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconButton(
              icon: state.isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              tooltip: state.isFullscreen
                  ? 'Thoát toàn màn hình'
                  : 'Toàn màn hình',
              onTap: _stateManager.toggleFullscreen,
            ),
            const SizedBox(width: 8),
            _buildIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Tải lại luồng',
              onTap: () => unawaited(_reloadStream()),
            ),
            const SizedBox(width: 8),
            _buildIconButton(
              icon: Icons.add_alert_rounded,
              tooltip: 'Tạo sự kiện thủ công',
              onTap: mainLoading ? null : () => unawaited(onMainTap()),
            ),
            const SizedBox(width: 8),
            _buildIconButton(
              icon: Icons.phone_in_talk,
              tooltip: 'Gọi khẩn cấp',
              onTap: _emergencyCalling
                  ? null
                  : () => unawaited(_handleEmergencyCall()),
            ),
            if (widget.mappedEventId?.isNotEmpty == true && !alarmActive) ...[
              const SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.notifications_active,
                tooltip: 'Kích hoạt báo động',
                onTap: _activatingAlarm
                    ? null
                    : () => unawaited(_onActivateAlarm()),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActionIconRow(CameraState state, bool fullscreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildIconButton(
          icon: state.isFullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          tooltip: state.isFullscreen ? 'Thoát toàn màn hình' : 'Toàn màn hình',
          onTap: _stateManager.toggleFullscreen,
        ),
        const SizedBox(width: 8),
        _buildIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Tải lại luồng',
          onTap: () => unawaited(_reloadStream()),
        ),
      ],
    );
  }

  /// Xây dựng icon button với style thống nhất
  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    double opacity = 0.10,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(opacity),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientActionButton({
    required IconData icon,
    required String label,
    required List<Color> colors,
    required Future<void> Function() onTap,
    bool loading = false,
    bool iconOnly = false,
  }) {
    return Container(
      height: iconOnly ? 44 : 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : () => unawaited(onTap()),
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white24,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? 12 : 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: iconOnly ? 22 : 20),
                if (!iconOnly) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
                if (loading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _downloadImageToLocalFile(String url, String cameraId) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        AppLogger.w('[Camera] Screenshot URL invalid: $url');
        return null;
      }

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              AppLogger.w('[Camera] Screenshot download timed out for $url');
              throw TimeoutException('Image download timeout');
            },
          );

      if (response.statusCode != 200) {
        AppLogger.w(
          '[Camera] Screenshot download failed (${response.statusCode}): $url',
        );
        return null;
      }
      if (response.bodyBytes.isEmpty) {
        AppLogger.w('[Camera] Screenshot download returned empty body');
        return null;
      }

      final thumbsDir = await CameraHelpers.getThumbsDirectory();
      final safeId = cameraId.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${thumbsDir.path}/camera_snapshot_${safeId}_$timestamp.jpg',
      );
      await file.writeAsBytes(response.bodyBytes, flush: true);

      AppLogger.i('[Camera] Remote screenshot saved: ${file.path}');
      return file.path;
    } catch (e, st) {
      AppLogger.e('[Camera] Failed to download screenshot: $e', e, st);
      return null;
    }
  }

  Widget _buildActionPanelBackground({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.18),
            Colors.black.withOpacity(0.45),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildActionPanelButtons(CameraState state, {bool iconOnly = false}) {
    const spacing = SizedBox(width: 12);
    return ValueListenableBuilder<bool>(
      valueListenable: ActiveAlarmNotifier.instance,
      builder: (context, _, __) {
        final status = AlarmStatusService.instance.statusNotifier.value;
        final alarmActive = _computeAlarmActive(status);
        // Common button definitions
        final captureLabel = _alarming ? 'Đang...' : 'CHỤP ẢNH';
        final captureIcon = Icons.warning_amber_rounded;
        final captureLoading = _alarming;

        // Icon-only (compact) layout: show emergency then cancel/capture beside it
        if (iconOnly) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconButton(
                icon: Icons.phone_in_talk,
                tooltip: 'Gọi khẩn cấp',
                onTap: _emergencyCalling
                    ? null
                    : () => unawaited(_handleEmergencyCall()),
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: alarmActive
                    ? Icons.close_rounded
                    : Icons.add_alert_rounded,
                tooltip: alarmActive ? 'Hủy báo động' : 'Tạo sự kiện thủ công',
                onTap: alarmActive
                    ? (_cancelingAlarm
                          ? null
                          : () => unawaited(_onCancelAlarm()))
                    : (_alarming
                          ? null
                          : () => unawaited(_onCaptureManualEvent())),
              ),
              if (widget.mappedEventId?.isNotEmpty == true && !alarmActive) ...[
                const SizedBox(width: 8),
                _buildIconButton(
                  icon: Icons.notifications_active,
                  tooltip: 'Kích hoạt báo động',
                  onTap: _activatingAlarm
                      ? null
                      : () => unawaited(_onActivateAlarm()),
                ),
              ],
            ],
          );
        }

        // Full (non-icon) layout: when an alarm is active, show Emergency + Cancel
        // on the top row and move Capture to its own full-width row below.
        if (alarmActive) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildGradientActionButton(
                      icon: Icons.phone_in_talk,
                      label: _emergencyCalling ? 'Đang...' : 'GỌI KHẨN CẤP',
                      colors: const [Color(0xFF26C6DA), Color(0xFF00ACC1)],
                      onTap: _handleEmergencyCall,
                      loading: _emergencyCalling,
                      iconOnly: iconOnly,
                    ),
                  ),
                  spacing,
                  Expanded(
                    child: _buildGradientActionButton(
                      icon: Icons.close_rounded,
                      label: _cancelingAlarm ? 'Đang hủy...' : 'HỦY BÁO ĐỘNG',
                      colors: const [Color(0xFFB0BEC5), Color(0xFF78909C)],
                      onTap: _onCancelAlarm,
                      loading: _cancelingAlarm,
                      iconOnly: iconOnly,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildGradientActionButton(
                      icon: captureIcon,
                      label: captureLabel,
                      colors: const [Color(0xFFFF7043), Color(0xFFEF4444)],
                      onTap: _onCaptureManualEvent,
                      loading: captureLoading,
                      iconOnly: false,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        // Default (no active alarm): original layout (Capture + Emergency),
        // with optional Activate Alarm below when mappedEventId exists.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildGradientActionButton(
                    icon: captureIcon,
                    label: captureLabel,
                    colors: const [Color(0xFFFF7043), Color(0xFFEF4444)],
                    onTap: _onCaptureManualEvent,
                    loading: captureLoading,
                    iconOnly: iconOnly,
                  ),
                ),
                spacing,
                Expanded(
                  child: _buildGradientActionButton(
                    icon: Icons.phone_in_talk,
                    label: _emergencyCalling ? 'Đang...' : 'GỌI KHẨN CẤP',
                    colors: const [Color(0xFF26C6DA), Color(0xFF00ACC1)],
                    onTap: _handleEmergencyCall,
                    loading: _emergencyCalling,
                    iconOnly: iconOnly,
                  ),
                ),
              ],
            ),
            // Activate alarm button (show when mappedEventId exists)
            if (widget.mappedEventId?.isNotEmpty == true && !alarmActive) ...[
              const SizedBox(height: 10),
              _buildGradientActionButton(
                icon: Icons.notifications_active,
                label: _activatingAlarm
                    ? 'Đang kích hoạt...'
                    : 'KÍCH HOẠT BÁO ĐỘNG',
                colors: const [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                onTap: _onActivateAlarm,
                loading: _activatingAlarm,
                iconOnly: iconOnly,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildInlineActionPanel(CameraState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: _buildActionPanelBackground(
            child: _buildActionPanelButtons(state, iconOnly: false),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoStack(CameraState state) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_currentPlayer != null)
              _currentPlayer!.buildView()
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _startPlay();
                },
                child: CameraWidgets.buildPlaceholder(),
              ),
            if (state.statusMessage != null)
              // Tương tự ở chế độ toàn màn hình: tránh hiển thị status chip
              // tạm thời gây che video.
              (() {
                final msg = state.statusMessage!.toLowerCase();
                final transient =
                    msg.contains('đang kết nối') ||
                    msg.contains('connecting') ||
                    msg.contains('đang phát') ||
                    msg.contains('playing');
                if (transient) return const SizedBox.shrink();
                return CameraStatusChip(text: state.statusMessage!);
              })(),
            // Positioned(
            //   top: 16,
            //   right: 16,
            //   child: QualityBadge(isHd: state.isHd, onTap: _toggleQuality),
            // ),
            if (state.isStarting)
              Container(
                color: Colors.black38,
                child: const Center(child: CircularProgressIndicator()),
              ),
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Quay về',
                ),
              ),
            ),
            _buildCameraActionOverlay(state, fullscreen: true),
          ],
        ),
      ),
    );
  }
}
