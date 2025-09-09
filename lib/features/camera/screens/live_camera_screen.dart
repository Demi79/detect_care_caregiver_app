import 'dart:async';
import 'dart:io';

import 'package:detect_care_caregiver_app/features/camera/widgets/controls_overlay.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/features_panel.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/quality_badge.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/status_chip.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline_panel.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/url_input_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LiveCameraScreen extends StatefulWidget {
  final String? initialUrl;
  const LiveCameraScreen({super.key, this.initialUrl});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  final TextEditingController _urlCtrl = TextEditingController();
  VlcPlayerController? _controller;
  bool _isPlaying = false;
  Timer? _statusTimer;
  bool _isMuted = false;
  bool _isFullscreen = false;
  bool _isHd = true; // HD (subtype=0) vs SD (subtype=1)
  bool _initLoading = true;
  bool _starting = false; // prevent concurrent play
  String? _currentUrl; // track currently playing URL
  bool _controlsVisible = true; // auto-hide playback controls
  Timer? _controlsTimer;
  String? _statusMsg; // status text shown on video
  static const String _kPrefHd = 'camera_hd_pref';
  static const String _kPrefFps = 'camera_fps_pref';
  int _fps = 25;
  // Bổ sung: thời gian lưu và kênh thông báo
  static const String _kPrefRetention = 'camera_retention_days';
  static const String _kPrefChannels = 'camera_notify_channels';
  int _retentionDays = 7; // mặc định 7 ngày
  Set<String> _channels = {'App'}; // kênh mặc định

  @override
  void initState() {
    super.initState();
    _restoreLastUrl();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_controller != null) {
        final playing = await _controller!.isPlaying();
        if (playing == true &&
            mounted &&
            (_statusMsg == null || _statusMsg != 'Đang phát')) {
          setState(() {
            _statusMsg = 'Đang phát';
          });
        }
      }
    });
  }

  Future<void> _restoreLastUrl() async {
    final prefs = await SharedPreferences.getInstance();
    // priority: initialUrl (if provided) then saved url
    final url = widget.initialUrl?.trim().isNotEmpty == true
        ? widget.initialUrl!.trim()
        : (prefs.getString('rtsp_url') ?? '');
    _urlCtrl.text = url;
    final subtype = _readSubtype(url);
    if (subtype == 0 || subtype == 1) {
      _isHd = subtype == 0;
    } else {
      // fall back to stored preference when URL doesn't contain subtype
      _isHd = prefs.getBool(_kPrefHd) ?? true;
    }
    final maybeFps = _tryReadFps(url);
    if (maybeFps != null) {
      _fps = maybeFps.clamp(5, 60);
    } else {
      _fps = (prefs.getInt(_kPrefFps) ?? 25).clamp(5, 60);
    }
    // Khôi phục thời gian lưu và kênh thông báo
    _retentionDays = (prefs.getInt(_kPrefRetention) ?? 7).clamp(1, 30);
    final chList = prefs.getStringList(_kPrefChannels) ?? ['App'];
    _channels = chList.toSet();
    setState(() => _initLoading = false);
    // auto-play if we have url from initial
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      await _startPlay();
    }
  }

  Future<void> _saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rtsp_url', url);
  }

  Future<void> _startPlay({bool allowFallback = true}) async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    if (_starting) return; // debounce
    if (_currentUrl == url && _controller != null) return; // no-op if same url
    _starting = true;
    setState(() {
      _statusMsg = _isHd ? 'Đang kết nối 1080P...' : 'Đang kết nối...';
      _isPlaying = false;
    });

    await _saveUrl(url);

    if (_controller != null) {
      try {
        await _controller!.stop();
      } catch (_) {}
      try {
        await _controller!.dispose();
      } catch (_) {}
      _controller = null;
    }

    await WakelockPlus.enable();

    try {
      _controller = VlcPlayerController.network(
        url,
        autoInitialize: true,
        autoPlay: true,
        hwAcc: HwAcc.full,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions(['--network-caching=300', '--rtsp-tcp']),
          // rtp: VlcRtpOptions(['--rtp-over-rtsp']), // removed invalid option
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _statusMsg = 'Không thể phát luồng';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể phát luồng. Kiểm tra URL.')),
        );
      }
      _starting = false;
      return;
    }

    _currentUrl = url;
    // Wait a short time for playback to actually start; fall back if needed.
    bool started = false;
    try {
      started = await _waitForPlayback(const Duration(seconds: 8));
    } catch (_) {}

    if (!mounted) {
      _starting = false;
      return;
    }

    if (started) {
      setState(() {
        _isPlaying = true;
        _isMuted = false;
        _statusMsg = 'Đang phát';
      });
      _starting = false;
      _showControlsTemporarily();
      return;
    }

    // Could not start. Optionally auto-fallback to SD if trying HD.
    if (allowFallback && _isHd) {
      final sdUrl = _withSubtype(url, 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể phát 1080P. Chuyển về SD...')),
      );
      setState(() {
        _isHd = false;
        _urlCtrl.text = sdUrl;
      });
      _starting = false;
      await _startPlay(allowFallback: false);
      return;
    }

    // Final failure
    setState(() {
      _statusMsg = 'Không thể phát luồng';
      _isPlaying = false;
    });
    _starting = false;
  }

  Future<bool> _waitForPlayback(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (mounted && DateTime.now().isBefore(deadline)) {
      try {
        final ok = await _controller?.isPlaying() ?? false;
        if (ok) return true;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return false;
  }

  int _readSubtype(String url) {
    try {
      final uri = Uri.parse(url);
      final subtypeStr = uri.queryParameters['subtype'];
      return int.tryParse(subtypeStr ?? '') ?? 0; // default main stream
    } catch (_) {
      return 0;
    }
  }

  String _withSubtype(String url, int subtype) {
    try {
      final uri = Uri.parse(url);
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['subtype'] = subtype.toString();
      return uri.replace(queryParameters: qp).toString();
    } catch (_) {
      return url;
    }
  }

  int? _tryReadFps(String url) {
    try {
      final uri = Uri.parse(url);
      final fpsStr = uri.queryParameters['fps'];
      final fps = int.tryParse(fpsStr ?? '');
      return fps;
    } catch (_) {
      return null;
    }
  }

  String _withFps(String url, int fps) {
    try {
      final uri = Uri.parse(url);
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['fps'] = fps.toString();
      return uri.replace(queryParameters: qp).toString();
    } catch (_) {
      return url;
    }
  }

  Future<void> _toggleQuality() async {
    if (_starting) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang kết nối, vui lòng đợi...')),
        );
      }
      return;
    }
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final nextHd = !_isHd;
    final targetSubtype = nextHd ? 0 : 1; // 0=HD(main), 1=SD(sub)
    final newUrl = _withSubtype(url, targetSubtype);
    if (mounted) setState(() => _isHd = nextHd);
    _urlCtrl.text = newUrl;
    // persist preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefHd, nextHd);
    } catch (_) {}
    if (newUrl != _currentUrl) {
      await _startPlay();
    }
    HapticFeedback.selectionClick();
  }

  Future<void> _changeFps(int newFps) async {
    if (_starting) return;
    _fps = newFps.clamp(5, 60);
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final newUrl = _withFps(url, _fps);
    if (mounted) setState(() => _urlCtrl.text = newUrl);
    // persist preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefFps, _fps);
    } catch (_) {}
    if (newUrl != _currentUrl) {
      await _startPlay();
    }
  }

  Future<void> _changeRetentionDays(int days) async {
    _retentionDays = days.clamp(1, 30);
    setState(() {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefRetention, _retentionDays);
    } catch (_) {}
  }

  Future<void> _changeChannels(Set<String> next) async {
    _channels = next;
    setState(() {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPrefChannels, _channels.toList());
    } catch (_) {}
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null) return;
    if (_isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
      _statusMsg = _isPlaying ? 'Đang phát' : 'Tạm dừng';
    });
    _showControlsTemporarily();
  }

  Future<void> _toggleMute() async {
    if (_controller == null) return;
    if (_isMuted) {
      await _controller!.setVolume(100);
    } else {
      await _controller!.setVolume(0);
    }
    setState(() => _isMuted = !_isMuted);
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    debugPrint('[LiveCameraScreen] dispose called');
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controlsTimer?.cancel();
    _statusTimer?.cancel();
    if (_controller != null) {
      final ctrl = _controller;
      _controller = null;
      ctrl!.dispose(); // Giải phóng ngay, tránh memory leak
    }
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (_isFullscreen) {
          await _toggleFullscreen();
          return;
        }
        try {
          if (_controller != null) {
            final bytes = await _controller!.takeSnapshot();
            if (bytes.isNotEmpty) {
              final dir = await getApplicationDocumentsDirectory();
              final thumbsDir = Directory('${dir.path}/thumbs');
              if (!await thumbsDir.exists()) {
                await thumbsDir.create(recursive: true);
              }
              final ts = DateTime.now().millisecondsSinceEpoch;
              int urlHash = 0;
              final urlStr = _currentUrl ?? _urlCtrl.text.trim();
              for (final code in urlStr.codeUnits) {
                urlHash = (urlHash * 31 + code) & 0x7fffffff;
              }
              final file = File(
                '${thumbsDir.path}/detect_care_thumb_${urlHash}_$ts.png',
              );
              await file.writeAsBytes(bytes, flush: true);
              await _cleanupOldThumbs(thumbsDir, keep: 50);
              if (context.mounted) {
                Navigator.of(context).pop(file.path);
              }
              return;
            }
          }
        } catch (_) {}
        if (context.mounted) Navigator.of(context).pop();
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Camera trực tiếp'),
            actions: [
              IconButton(
                onPressed: _toggleFullscreen,
                icon: Icon(
                  _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
              ),
            ],
          ),
          body: _isFullscreen
              ? SafeArea(
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    height: double.infinity,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showControlsTemporarily,
                      onDoubleTap: _toggleFullscreen,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_controller != null)
                            VlcPlayer(
                              controller: _controller!,
                              aspectRatio: 16 / 9,
                              placeholder: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else
                            _placeholder(),
                          if (_statusMsg != null)
                            CameraStatusChip(text: _statusMsg!),
                          QualityBadge(isHd: _isHd, onTap: _toggleQuality),
                          if (_starting)
                            Container(
                              color: Colors.black38,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          // Nút back nổi khi fullscreen
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
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                tooltip: 'Quay về',
                              ),
                            ),
                          ),
                          if (_controlsVisible)
                            Builder(
                              builder: (context) => CameraControlsOverlay(
                                isPlaying: _isPlaying,
                                isMuted: _isMuted,
                                isFullscreen: _isFullscreen,
                                onPlayPause: _togglePlayPause,
                                onMute: _toggleMute,
                                onFullscreen: _toggleFullscreen,
                                onRecord: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ghi hình chưa hỗ trợ.'),
                                    ),
                                  );
                                },
                                onSnapshot: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Chụp ảnh chưa hỗ trợ.'),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    UrlInputRow(
                      controller: _urlCtrl,
                      starting: _starting,
                      onStart: () => _startPlay(),
                    ),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: Colors.black,
                        width: double.infinity,
                        child: _initLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _controller == null
                            ? _placeholder()
                            : GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _showControlsTemporarily,
                                onDoubleTap: _toggleFullscreen,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    VlcPlayer(
                                      controller: _controller!,
                                      aspectRatio: 16 / 9,
                                      placeholder: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    if (_statusMsg != null)
                                      CameraStatusChip(text: _statusMsg!),
                                    QualityBadge(
                                      isHd: _isHd,
                                      onTap: _toggleQuality,
                                    ),
                                    if (_starting)
                                      Container(
                                        color: Colors.black38,
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                    if (_controlsVisible)
                                      Builder(
                                        builder: (context) =>
                                            CameraControlsOverlay(
                                              isPlaying: _isPlaying,
                                              isMuted: _isMuted,
                                              isFullscreen: _isFullscreen,
                                              onPlayPause: _togglePlayPause,
                                              onMute: _toggleMute,
                                              onFullscreen: _toggleFullscreen,
                                              onRecord: () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Ghi hình chưa hỗ trợ.',
                                                    ),
                                                  ),
                                                );
                                              },
                                              onSnapshot: () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Chụp ảnh chưa hỗ trợ.',
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const TabBar(
                      labelColor: Colors.orange,
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(text: 'Tính năng'),
                        Tab(text: 'Danh sách'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          CameraFeaturesPanel(
                            fps: _fps,
                            onFpsChanged: _changeFps,
                            retentionDays: _retentionDays,
                            onRetentionChanged: _changeRetentionDays,
                            channels: _channels,
                            onChannelsChanged: _changeChannels,
                          ),
                          const CameraTimelinePanel(),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_outlined, size: 64, color: Colors.white70),
            SizedBox(height: 12),
            Text(
              'Nhập URL RTSP/HTTP của camera để bắt đầu phát',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  // Local button/status widgets moved to lib/features/camera/widgets

  void _showControlsTemporarily() {
    setState(() => _controlsVisible = true);
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  // Panels moved into widgets under lib/features/camera/widgets
}

extension on _LiveCameraScreenState {
  Future<void> _cleanupOldThumbs(Directory thumbsDir, {int keep = 50}) async {
    try {
      final entries = await thumbsDir.list().where((e) => e is File).toList();
      final files = entries.cast<File>();
      if (files.length <= keep) return;
      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      for (final f in files.skip(keep)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}
