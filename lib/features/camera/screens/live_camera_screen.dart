import 'dart:async';
import 'dart:ui';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/alarm/data/alarm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_core.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/camera_timeline_screen.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_access_guard.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/features_panel.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/status_chip.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_context.dart';
import 'package:detect_care_caregiver_app/features/emergency/call_action_service.dart';
import 'package:detect_care_caregiver_app/features/emergency_contacts/data/emergency_contacts_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/alarm/services/active_alarm_notifier.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

/// Màn hình camera chính với kiến trúc module hóa
class LiveCameraScreen extends StatefulWidget {
  final String? initialUrl;
  final bool loadCache;
  final CameraEntry? camera;
  final String? mappedEventId;

  const LiveCameraScreen({
    super.key,
    this.initialUrl,
    this.loadCache = true,
    this.camera,
    this.mappedEventId,
  });

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  late final CameraStateManager _stateManager;
  late final CameraService _cameraService;
  late final CameraAccessGuard _accessGuard;
  bool _prevIsFullscreen = false;
  bool _handlingFullscreen = false;
  Timer? _startDebounce;
  bool _streamDisposed = false;
  bool _stateDisposed = false;
  bool _alarming = false;
  bool _emergencyCalling = false;
  bool _infraredEnabled = false;
  bool _cancelingAlarm = false;

  @override
  void initState() {
    super.initState();
    // Nếu `initialUrl` được truyền vào, ưu tiên nó thay vì phục hồi
    // URL/cấu hình đã lưu trước đó. Trong trường hợp đó, tắt loadCache.
    final shouldLoadCache = widget.initialUrl == null && widget.loadCache;
    _stateManager = CameraStateManager(loadCache: shouldLoadCache);
    // Use the shared singleton service so all modules observe the same
    // VlcPlayerController instance (avoids situations where UI/debug
    // shows `controller=null` because a different CameraService was used).
    _cameraService = cameraService;
    _accessGuard = CameraAccessGuard();
    _stateManager.init();

    // Nếu có initial URL, gán vào controller để màn hình dùng URL này
    // thay vì giá trị đã lưu, và có thể auto-play.
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _stateManager.urlController.text = widget.initialUrl!;
      _stateManager.setCurrentUrl(widget.initialUrl!);
      // Start playback automatically when initialUrl is supplied.
      _startPlay();
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

      // Try to ensure (warm) controller for the URL. The service may
      // return an existing controller or create a new one and wait briefly.
      final ensured = await _cameraService.ensureControllerFor(
        url,
        waitFor: const Duration(seconds: 2),
      );

      if (ensured != null) {
        // Use the ensured controller for the UI
        _stateManager.setController(ensured);

        // Give native side a small moment and check playback safely
        await Future.delayed(const Duration(milliseconds: 400));
        final playing = await cameraService.safeIsPlaying(ensured);
        AppLogger.d('🐛 [Camera] warm ensured playing=$playing');
        if (playing == true) {
          _stateManager.setStarting(false);
          return;
        }
      }

      // Warm failed or not playing yet — fallback to recreate (safe)
      AppLogger.d(
        '🐛 [Camera] warm failed; recreating for fullscreen url=$url',
      );
      await _disposeStreamResources();
      await Future.delayed(const Duration(milliseconds: 200));
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

  Future<void> _startPlay({bool allowFallback = true}) async {
    // Đảm bảo người dùng có quyền (gói) trước khi thử phát
    final allowed = await _accessGuard.ensureSubscriptionAllowed(context);
    if (!allowed) return;

    final url = _stateManager.urlController.text.trim();
    if (url.isEmpty) return;

    if (_stateManager.isStarting) {
      return; // debounce
    }
    if (_stateManager.currentUrl == url && _cameraService.controller != null) {
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
      final controller = await _cameraService.createController(url);
      _stateManager.setController(controller);

      // Listen for video size changes
      controller.addListener(() {
        final size = controller.value.size;
        if (size.width > 0 && size.height > 0) {
          final newAspectRatio = size.width / size.height;
          if (_stateManager.videoAspectRatio != newAspectRatio) {
            _stateManager.setVideoAspectRatio(newAspectRatio);
          }
        }
      });

      final started = await _cameraService.waitForPlayback(
        CameraConstants.playbackWaitTimeout,
      );

      if (!mounted) return;

      if (started) {
        // Phát lại đã bắt đầu thành công. KHÔNG hiển thị status chip lớn
        // (có thể che luồng video). Vẫn hiển thị controls tạm thời nhưng
        // tránh đặt thông báo trạng thái cố định.
        _stateManager.showControlsTemporarily();
        // Xóa mọi status tạm thời trước đó để giao diện không bị che.
        _stateManager.setStatusMessage(null);
        // Quan trọng: tắt flag "starting" để overlay loading không còn hiển
        // thị nữa.
        _stateManager.setStarting(false);
        return;
      }

      // Fallback to SD if HD fails
      if (allowFallback && _stateManager.isHd) {
        final sdUrl = CameraHelpers.withSubtype(url, CameraConstants.sdSubtype);
        // context.showCameraMessage(CameraConstants.hdFallbackMessage);
        _stateManager.updateSettings(isHd: false);
        _stateManager.urlController.text = sdUrl;
        _stateManager.setStarting(false);
        await _startPlay(allowFallback: false);
        return;
      }

      _stateManager.setStatusMessage(CameraConstants.cannotPlayMessage);
    } catch (e) {
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

  Future<void> _toggleQuality() async {
    if (_stateManager.isStarting) {
      context.showCameraMessage(CameraConstants.connectingWaitMessage);
      return;
    }

    final url = _stateManager.urlController.text.trim();
    if (url.isEmpty) return;

    final nextHd = !_stateManager.isHd;
    final targetSubtype = nextHd
        ? CameraConstants.hdSubtype
        : CameraConstants.sdSubtype;
    final newUrl = CameraHelpers.withSubtype(url, targetSubtype);

    _stateManager.updateSettings(isHd: nextHd);
    _stateManager.urlController.text = newUrl;

    if (newUrl != _stateManager.currentUrl) {
      await _startPlay();
    }

    HapticFeedback.selectionClick();
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
    try {
      snapshotPath = await _cameraService.takeSnapshot();
      if (snapshotPath == null) {
        context.showCameraMessage('Không chụp được khung hình.');
        return;
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
      if (cameraId == '0fd3f12d-ef70-4d41-a622-79fa5db67a49') {
        print(
          '🐛 [Camera] using default cameraId fallback (extracted=$extracted)',
        );
      }

      if (widget.mappedEventId != null && widget.mappedEventId!.isNotEmpty) {
        final eventId = widget.mappedEventId!;
        try {
          await EventsRemoteDataSource().updateEventLifecycle(
            eventId: eventId,
            lifecycleState: 'ALARM_ACTIVATED',
            notes: 'Activated from camera live view',
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
          }
        } catch (e, st) {
          AppLogger.e('Failed to activate mapped event alarm: $e', e, st);
          if (mounted) {
            context.showCameraMessage('Kích hoạt báo động thất bại.');
          }
        }
      } else {
        final svc = EventService.withDefaultClient();
        final createdEvent = await svc.sendManualAlarm(
          cameraId: cameraId,
          snapshotPath: snapshotPath,
          cameraName: widget.camera?.name ?? 'Camera',
          streamUrl: _stateManager.currentUrl,
        );

        try {
          final userId = await AuthStorage.getUserId();
          if (userId != null && userId.isNotEmpty) {
            try {
              await AlarmRemoteDataSource().setAlarm(
                eventId: createdEvent.eventId,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gửi báo động thành công.')),
        );
      }
    } catch (e, st) {
      AppLogger.e('❌ [Camera] send manual alarm failed', e, st);
      if (mounted) context.showCameraMessage('Gửi báo động thất bại.');
    } finally {
      if (mounted) setState(() => _alarming = false);
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      final isPlaying = _stateManager.state.isPlaying;
      await _cameraService.togglePlayPause(isPlaying);
    } catch (e, st) {
      AppLogger.e('Failed to toggle play/pause', e, st);
    }
  }

  Future<void> _reloadStream() async {
    try {
      await _disposeStreamResources();
      await Future.delayed(const Duration(milliseconds: 150));
      await _startPlay();
    } catch (e, st) {
      AppLogger.e('Failed to reload stream', e, st);
    }
  }

  Future<void> _onCaptureAndAlarm() async {
    setState(() => _alarming = true);
    String? snapshotPath;
    try {
      snapshotPath = await _cameraService.takeSnapshot();
      if (snapshotPath == null) {
        if (mounted) context.showCameraMessage('Không chụp được khung hình.');
        return;
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
      if (cameraId == '0fd3f12d-ef70-4d41-a622-79fa5db67a49') {
        AppLogger.d(
          '🐛 [Camera] using default cameraId fallback (extracted=$extracted)',
        );
      }

      if (widget.mappedEventId != null && widget.mappedEventId!.isNotEmpty) {
        final eventId = widget.mappedEventId!;
        try {
          await EventsRemoteDataSource().updateEventLifecycle(
            eventId: eventId,
            lifecycleState: 'ALARM_ACTIVATED',
            notes: 'Activated from camera live view',
          );

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
          }
        } catch (e, st) {
          AppLogger.e('Failed to activate mapped event alarm: $e', e, st);
          if (mounted) {
            context.showCameraMessage('Kích hoạt báo động thất bại.');
          }
        }
      } else {
        final svc = EventService.withDefaultClient();
        final createdEvent = await svc.sendManualAlarm(
          cameraId: cameraId,
          snapshotPath: snapshotPath,
          cameraName: widget.camera?.name ?? 'Camera',
          streamUrl: _stateManager.currentUrl,
        );

        try {
          final userId = await AuthStorage.getUserId();
          if (userId != null && userId.isNotEmpty) {
            try {
              await AlarmRemoteDataSource().setAlarm(
                eventId: createdEvent.eventId,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gửi báo động thành công.')),
        );
      }
    } catch (e, st) {
      AppLogger.e('❌ [Camera] send manual alarm failed', e, st);
      if (mounted) context.showCameraMessage('Gửi báo động thất bại.');
    } finally {
      if (mounted) setState(() => _alarming = false);
    }
  }

  Future<void> _toggleMute() async {
    await _cameraService.toggleMute(_stateManager.isMuted);
  }

  void _toggleInfrared() {
    setState(() => _infraredEnabled = !_infraredEnabled);
    if (!mounted) return;
    context.showCameraMessage(
      _infraredEnabled ? 'Đã bật hồng ngoại.' : 'Đã tắt hồng ngoại.',
    );
  }

  Future<void> _handleEmergencyCall() async {
    setState(() => _emergencyCalling = true);
    try {
      final manager = callActionManager(context);
      if (!manager.allowedActions.contains(CallAction.emergency)) {
        if (mounted) {
          context.showCameraMessage(
            'Trong trường hợp khẩn cấp, hệ thống sẽ liên hệ người chăm sóc trước.',
          );
        }
        return;
      }

      final phone = await _chooseEmergencyPhone();
      await attemptCall(
        context: context,
        rawPhone: phone,
        actionLabel: 'Gọi khẩn cấp',
      );
    } catch (e, st) {
      AppLogger.e('[Camera] emergency call failed', e, st);
      if (mounted) context.showCameraMessage('Không thể thực hiện cuộc gọi.');
    } finally {
      if (mounted) setState(() => _emergencyCalling = false);
    }
  }

  Future<String> _chooseEmergencyPhone() async {
    String phone = '115';
    try {
      final userId = await AuthStorage.getUserId();
      if (userId != null && userId.isNotEmpty) {
        final list = await EmergencyContactsRemoteDataSource().list(userId);
        if (list.isNotEmpty) {
          list.sort((a, b) => b.alertLevel.compareTo(a.alertLevel));
          EmergencyContactDto? chosen;
          for (final c in list) {
            if (c.phone.trim().isNotEmpty) {
              chosen = c;
              break;
            }
          }
          chosen ??= list.first;
          if (chosen.phone.trim().isNotEmpty) {
            phone = chosen.phone.trim();
          }
        }
      }
    } catch (_) {}
    return phone.isEmpty ? '115' : phone;
  }

  Future<void> _onCancelAlarm() async {
    final eventId = widget.mappedEventId;
    if (eventId == null || eventId.isEmpty) return;
    if (_cancelingAlarm) return;
    setState(() => _cancelingAlarm = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Đang hủy báo động...')),
      );

      await EventsRemoteDataSource().cancelEvent(eventId: eventId);

      try {
        final userId = await AuthStorage.getUserId();
        if (userId != null && userId.isNotEmpty) {
          await AlarmRemoteDataSource().cancelAlarm(
            eventId: eventId,
            userId: userId,
            cameraId: null,
          );
        }
      } catch (e) {
        AppLogger.e('External cancel alarm failed: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã hủy báo động.')));
      }
    } catch (e, st) {
      AppLogger.e('Failed to cancel mapped event alarm: $e', e, st);
      if (mounted) context.showCameraMessage('Hủy báo động thất bại.');
    } finally {
      if (mounted) setState(() => _cancelingAlarm = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          snapshotPath = await _cameraService.takeSnapshot();
        } catch (_) {}

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
        // Nếu chưa có controller (placeholder), để null để cho inner
        // GestureDetector (nhấn để bắt phát) nhận sự kiện.
        onTap: _cameraService.controller != null
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
    final isOnline = _cameraService.controller != null && !state.initLoading;

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
    final hasController = _cameraService.controller != null;

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
                  if (hasController)
                    VlcPlayer(
                      controller: _cameraService.controller!,
                      aspectRatio: state.videoAspectRatio ?? 16 / 9,
                      placeholder: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
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
        _buildCircleIconButton(
          icon: state.isFullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          tooltip: state.isFullscreen ? 'Thoát toàn màn hình' : 'Toàn màn hình',
          onTap: _stateManager.toggleFullscreen,
        ),
        const SizedBox(width: 8),
        _buildCircleIconButton(
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
          Text(
            'LIVE',
            style: const TextStyle(
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
    final horizontalPadding = fullscreen ? 20.0 : 12.0;
    final verticalPadding = fullscreen ? 24.0 : 14.0;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionIconRow(state, fullscreen),
                  const SizedBox(height: 12),
                  _buildActionPanelButtons(state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionIconRow(CameraState state, bool fullscreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const SizedBox(width: 8),
            _buildCircleIconButton(
              icon: fullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              tooltip: fullscreen ? 'Thoát toàn màn hình' : 'Toàn màn hình',
              onTap: _stateManager.toggleFullscreen,
            ),
          ],
        ),
        Row(
          children: [
            _buildCircleIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Tải lại luồng',
              onTap: () => unawaited(_reloadStream()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.10),
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
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : () => unawaited(onTap()),
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.white24,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
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
    );
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

  Widget _buildActionPanelButtons(CameraState state) {
    const spacing = SizedBox(width: 12);
    return ValueListenableBuilder<bool>(
      valueListenable: ActiveAlarmNotifier.instance,
      builder: (context, alarmActive, _) {
        final mainGradient = alarmActive
            ? const [Color(0xFFB0BEC5), Color(0xFF78909C)]
            : const [Color(0xFFFF7043), Color(0xFFEF4444)];
        final mainLabel = alarmActive
            ? (_cancelingAlarm ? 'Đang hủy...' : 'HỦY BÁO ĐỘNG')
            : (_alarming ? 'Đang...' : 'BÁO ĐỘNG');
        final showCancelButton =
            widget.mappedEventId?.isNotEmpty == true && !alarmActive;
        final onMainTap = alarmActive ? _onCancelAlarm : _onCaptureAndAlarm;
        final mainLoading = alarmActive ? _cancelingAlarm : _alarming;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildGradientActionButton(
                    icon: Icons.warning_amber_rounded,
                    label: mainLabel,
                    colors: mainGradient,
                    onTap: onMainTap,
                    loading: mainLoading,
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
                  ),
                ),
              ],
            ),
            if (showCancelButton) ...[
              const SizedBox(height: 10),
              _buildGradientActionButton(
                icon: Icons.cancel_presentation_rounded,
                label: _cancelingAlarm ? 'Đang hủy...' : 'HỦY BÁO ĐỘNG',
                colors: const [Color(0xFFB0BEC5), Color(0xFF78909C)],
                onTap: _onCancelAlarm,
                loading: _cancelingAlarm,
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
            child: _buildActionPanelButtons(state),
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
            if (_cameraService.controller != null)
              VlcPlayer(
                controller: _cameraService.controller!,
                aspectRatio: state.videoAspectRatio ?? 16 / 9,
                placeholder: const Center(child: CircularProgressIndicator()),
              )
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
