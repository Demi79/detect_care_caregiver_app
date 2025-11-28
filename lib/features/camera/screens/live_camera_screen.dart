import 'dart:async';

import 'package:detect_care_caregiver_app/core/services/direct_caller.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/screens/phone_login_screen.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_core.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/camera_timeline_screen.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_access_guard.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/controls_overlay.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/features_panel.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/quality_badge.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/status_chip.dart';
import 'package:detect_care_caregiver_app/features/emergency_contacts/data/emergency_contacts_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:permission_handler/permission_handler.dart';

/// Màn hình camera chính với kiến trúc module hóa
class LiveCameraScreen extends StatefulWidget {
  final String? initialUrl;
  final bool loadCache;
  final CameraEntry? camera;

  const LiveCameraScreen({
    super.key,
    this.initialUrl,
    this.loadCache = true,
    this.camera,
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CameraTimelineScreen(camera: camera)),
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
        context.showCameraMessage(CameraConstants.hdFallbackMessage);

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
  }

  Future<void> _togglePlayPause() async {
    await _cameraService.togglePlayPause(_stateManager.isPlaying);
    _stateManager.showControlsTemporarily();
  }

  Future<void> _reloadStream() async {
    // Explicit user-triggered reload: dispose current resources and restart.
    if (_stateManager.isStarting) {
      context.showCameraMessage('Đang thực hiện thao tác. Vui lòng chờ.');
      return;
    }

    try {
      await _disposeStreamResources();
      // small delay to allow native resources to free
      await Future.delayed(const Duration(milliseconds: 250));
      await _startPlay();
    } catch (e, st) {
      AppLogger.e('🐛 [Camera] reloadStream error', e, st);
      context.showCameraMessage('Không thể tải lại luồng.');
    }
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

  Future<void> _onCaptureAndAlarm() async {
    if (_alarming) return;
    if (_cameraService.controller == null) {
      context.showCameraMessage('Chưa có luồng camera để chụp.');
      return;
    }

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
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12} '
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

      final svc = EventService.withDefaultClient();
      await svc.sendManualAlarm(
        cameraId: cameraId,
        snapshotPath: snapshotPath,
        cameraName: "Phòng khách",
        streamUrl: _stateManager.currentUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gửi báo động thành công.')));
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

  Future<void> _handleEmergencyCall() async {
    try {
      String phone = '115';

      try {
        final userId = await AuthStorage.getUserId();
        if (userId != null && userId.isNotEmpty) {
          try {
            final ds = EmergencyContactsRemoteDataSource();
            final list = await ds.list(userId);
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
          } catch (_) {}
        }
      } catch (_) {}

      String normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (normalized.startsWith('+84')) {
        normalized = '0${normalized.substring(3)}';
      } else if (normalized.startsWith('84')) {
        normalized = '0${normalized.substring(2)}';
      }

      final status = await Permission.phone.request();
      if (status.isGranted) {
        final success = await DirectCaller.call(normalized);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Đang gọi $normalized...')));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không thể thực hiện cuộc gọi trực tiếp.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else if (status.isPermanentlyDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Quyền gọi điện bị từ chối vĩnh viễn. Vui lòng bật quyền trong cài đặt.',
            ),
            action: SnackBarAction(
              label: 'Cài đặt',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quyền gọi điện bị từ chối.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e, st) {
      AppLogger.e('[Camera] emergency call failed', e, st);
      if (mounted) context.showCameraMessage('Không thể thực hiện cuộc gọi.');
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
            child: CameraWidgets.buildNormalContainer(
              aspectRatio: state.videoAspectRatio,
              child: _buildVideoContent(state),
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
                // Lưu ý: thời gian lưu trữ được cấu hình ở Image settings; ẩn
                // tuỳ chọn này trong panel camera để tránh trùng lặp.
                showRetention: false,
                timelineContent: _buildEmbeddedTimeline(context),
                onOpenTimeline: widget.camera != null ? _openTimeline : null,
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

  Widget _buildVideoContent(CameraState state) {
    if (state.initLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cameraService.controller == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Nếu người dùng nhấn placeholder, thử khởi phát (nếu có URL)
          _startPlay();
        },
        child: CameraWidgets.buildPlaceholder(),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _stateManager.showControlsTemporarily,
      onDoubleTap: _stateManager.toggleFullscreen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: VlcPlayer(
              controller: _cameraService.controller!,
              aspectRatio: state.videoAspectRatio ?? 16 / 9,
              placeholder: const Center(child: CircularProgressIndicator()),
            ),
          ),
          if (state.statusMessage != null)
            // Chỉ hiển thị status chip lớn cho các thông báo không tạm thời
            // (ví dụ: lỗi). Các thông báo tạm thời như "Đang kết nối" hoặc
            // "Đang phát" sẽ che video, nên bỏ qua hiển thị chip cho chúng.
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
          Positioned(
            top: 12,
            right: 12,
            child: QualityBadge(isHd: state.isHd, onTap: _toggleQuality),
          ),
          if (state.isStarting)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (state.controlsVisible)
            Builder(
              builder: (context) => CameraControlsOverlay(
                isPlaying: state.isPlaying,
                isMuted: state.isMuted,
                isFullscreen: state.isFullscreen,
                onPlayPause: _togglePlayPause,
                onMute: _toggleMute,
                onFullscreen: _stateManager.toggleFullscreen,
                onReload: _reloadStream,
                onRecord: () {
                  context.showCameraMessage(
                    CameraConstants.recordNotSupportedMessage,
                  );
                },
                onSnapshot: () {
                  context.showCameraMessage(
                    CameraConstants.snapshotNotSupportedMessage,
                  );
                },
                onAlarm: _onCaptureAndAlarm,
                onEmergency: _handleEmergencyCall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoStack(CameraState state) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
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
          Positioned(
            top: 16,
            right: 16,
            child: QualityBadge(isHd: state.isHd, onTap: _toggleQuality),
          ),
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
          if (state.controlsVisible)
            Builder(
              builder: (context) => CameraControlsOverlay(
                isPlaying: state.isPlaying,
                isMuted: state.isMuted,
                isFullscreen: state.isFullscreen,
                onPlayPause: _togglePlayPause,
                onMute: _toggleMute,
                onFullscreen: _stateManager.toggleFullscreen,
                onReload: _reloadStream,
                onRecord: () {
                  context.showCameraMessage(
                    CameraConstants.recordNotSupportedMessage,
                  );
                },
                onSnapshot: () {
                  context.showCameraMessage(
                    CameraConstants.snapshotNotSupportedMessage,
                  );
                },
                onAlarm: _onCaptureAndAlarm,
                onEmergency: _handleEmergencyCall,
              ),
            ),
        ],
      ),
    );
  }
}
