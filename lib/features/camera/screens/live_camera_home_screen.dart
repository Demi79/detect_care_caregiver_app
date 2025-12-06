import 'dart:async';

import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/camera_timeline_screen.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/live_camera_screen.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_home_state.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_quota_service.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_service.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/add_camera_dialog.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/camera_layouts.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/camera_views.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/controls_bar.dart';
import 'package:detect_care_caregiver_app/features/subscription/data/service_package_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _CameraHomeMenuOption {
  toggleView,
  toggleSort,
  refreshThumbnails,
  settings,
}

class LiveCameraHomeScreen extends StatefulWidget {
  const LiveCameraHomeScreen({super.key});

  @override
  State<LiveCameraHomeScreen> createState() => _LiveCameraHomeScreenState();
}

class _LiveCameraHomeScreenState extends State<LiveCameraHomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final CameraHomeState _state;
  late final VoidCallback _stateListener;
  late final AnimationController _fabAnimationController;
  late final Animation<double> _fabAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _state = CameraHomeState(
      CameraService(),
      CameraQuotaService(ServicePackageApi()),
    );
    _stateListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _state.addListener(_stateListener);
    _state.loadCameras().then((_) {
      if (!mounted) return;
      _precacheThumbnails(6);
    });

    // Setup FAB animation
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fabAnimationController.forward();
  }

  Future<void> _precacheThumbnails(int limit) async {
    try {
      final cameras = _state.cameras;
      var count = 0;
      for (final c in cameras) {
        final url = c.thumb;
        if (url != null && url.startsWith('http')) {
          try {
            await precacheImage(NetworkImage(url), context);
          } catch (e) {
            debugPrint('Precache failed for $url: $e');
          }
          count++;
          if (count >= limit) break;
        }
      }
    } catch (e) {
      debugPrint('Error during precache thumbnails: $e');
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _state.removeListener(_stateListener);
    _state.dispose();
    super.dispose();
  }

  Future<void> _playCamera(CameraEntry camera) async {
    if (!mounted) return;

    debugPrint(
      '[LiveCameraHomeScreen] Opening LiveCameraScreen for: ${camera.name}',
    );
    // Remove any previously saved RTSP URL so the new screen doesn't restore it
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('rtsp_url');
    } catch (e) {
      debugPrint('Failed to clear saved RTSP URL: $e');
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => LiveCameraScreen(
          initialUrl: camera.url,
          loadCache: false, // Don't load cache when opening from list
          camera: camera,
        ),
        settings: const RouteSettings(name: 'live_camera_screen'),
      ),
    );

    // Handle result from LiveCameraScreen (snapshot path if taken)
    if (result != null && mounted) {
      debugPrint('[LiveCameraHomeScreen] Snapshot taken: $result');
    }

    // Force refresh thumbnails after returning from camera screen
    if (mounted) {
      await _state.refreshThumbnails();
    }
  }

  Future<void> _openCameraTimeline(CameraEntry camera) async {
    if (!mounted) return;
    await _state.refreshCameraThumb(camera);
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CameraTimelineScreen(camera: camera),
        settings: const RouteSettings(name: 'camera_timeline_screen'),
      ),
    );
  }

  void _onMenuOptionSelected(_CameraHomeMenuOption option) {
    if (!mounted) return;
    switch (option) {
      case _CameraHomeMenuOption.toggleView:
        HapticFeedback.selectionClick();
        _state.toggleView();
        break;
      case _CameraHomeMenuOption.toggleSort:
        HapticFeedback.selectionClick();
        _state.toggleSort();
        break;
      case _CameraHomeMenuOption.refreshThumbnails:
        if (_state.refreshing) return;
        HapticFeedback.mediumImpact();
        _state.refreshThumbnails();
        break;
      case _CameraHomeMenuOption.settings:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cài đặt đang được phát triển.')),
        );
        break;
    }
  }

  Future<void> _editCamera(CameraEntry camera) async {
    if (!mounted) return;

    final cameraData = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AddCameraDialog(
        initialData: {
          'camera_name': camera.name,
          'rtsp_url': camera.url,
          'username': '',
          'password': '',
        },
      ),
    );

    if (!mounted) return;

    if (cameraData != null) {
      try {
        await _state.updateCamera(camera.id, cameraData);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã cập nhật camera: ${cameraData['camera_name'] ?? ''}',
            ),
          ),
        );
      } catch (e) {
        debugPrint('[API] Error updating camera: $e');
        if (!mounted) return;
        final message = kDebugMode
            ? 'Lỗi cập nhật camera: $e'
            : 'Lỗi cập nhật camera';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _addCamera() async {
    final userId = await AuthStorage.getUserId();
    if (!mounted) return;

    // Đảm bảo quota đã được validate
    if (_state.quotaValidation == null) {
      await _state.validateCameraQuota();
      if (!mounted) return;
    }

    // Kiểm tra quota trước khi hiển thị dialog
    if (_state.quotaValidation != null && !_state.quotaValidation!.canAdd) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _state.quotaValidation!.message ?? 'Không thể thêm camera',
          ),
          action: _state.quotaValidation!.shouldUpgrade
              ? SnackBarAction(label: 'Nâng cấp', onPressed: _upgradePlan)
              : null,
        ),
      );
      return;
    }

    final cameraData = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AddCameraDialog(userId: userId),
    );

    if (!mounted) return;

    debugPrint('[ADD CAMERA] userId: $userId, cameraData: $cameraData');

    if (cameraData != null) {
      try {
        await _state.addCamera(cameraData);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm camera: ${cameraData['camera_name'] ?? ''}'),
          ),
        );
      } catch (e) {
        debugPrint('[API] Error creating camera: $e');
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo camera: $e')));
      }
    } else {
      debugPrint('[ADD CAMERA] No camera data provided');
    }
  }

  Future<void> _upgradePlan() async {
    // Navigate to subscription screen
    if (!mounted) return;

    // TODO: Navigate to subscription/upgrade screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng nâng cấp sẽ được triển khai')),
    );
  }

  Future<void> _confirmAndRemove(CameraEntry camera) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa camera'),
        content: Text('Bạn có chắc muốn xóa camera "${camera.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _state.deleteCamera(camera);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa "${camera.name}"'),
            action: SnackBarAction(
              label: 'Hoàn tác',
              onPressed: () {
                if (!mounted) return;
                _state.undoDelete(camera.id);
              },
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa camera: $e')));
      }
    }
  }

  void _onSearchChanged(String value) {
    if (!mounted) return;
    _state.updateSearch(value);
  }

  Widget _buildContentView(List<CameraEntry> cameras) {
    final statusNote = _state.lastRefreshed == null
        ? 'Chưa đồng bộ'
        : 'Cập nhật ${_formatRelativeTime(_state.lastRefreshed!)}';
    return RefreshIndicator(
      key: const ValueKey('content'),
      color: Colors.blueAccent,
      backgroundColor: Colors.white,
      onRefresh: () async {
        if (!mounted) return;
        await _state.loadCameras();
        await _state.refreshThumbnails();
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ControlsBar(
              search: _state.search,
              onSearchChanged: _onSearchChanged,
              lastRefreshed: _state.lastRefreshed,
              total: _state.cameras.length,
              filtered: cameras.length,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            sliver: _state.grid
                ? CameraGrid(
                    cameras: cameras,
                    onPlay: (camera) {
                      if (!mounted) return;
                      _playCamera(camera);
                    },
                    onDelete: (camera) {
                      if (!mounted) return;
                      _confirmAndRemove(camera);
                    },
                    onEdit: (camera) {
                      if (!mounted) return;
                      _editCamera(camera);
                    },
                    onRefreshRequested: (camera) {
                      if (!mounted) return;
                      _state.refreshCameraThumb(camera);
                    },
                    onShowTimeline: (camera) {
                      if (!mounted) return;
                      _openCameraTimeline(camera);
                    },
                    searchQuery: _state.search,
                    statusNote: statusNote,
                  )
                : CameraList(
                    cameras: cameras,
                    onPlay: (camera) {
                      if (!mounted) return;
                      _playCamera(camera);
                    },
                    onDelete: (camera) {
                      if (!mounted) return;
                      _confirmAndRemove(camera);
                    },
                    onEdit: (camera) {
                      if (!mounted) return;
                      _editCamera(camera);
                    },
                    onShowTimeline: (camera) {
                      if (!mounted) return;
                      _openCameraTimeline(camera);
                    },
                    searchQuery: _state.search,
                    statusNote: statusNote,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(List<CameraEntry> filteredCameras) {
    final total = _state.cameras.length;
    if (total == 0) return const SizedBox.shrink();
    final onlineCount = _state.cameras.where((c) => c.isOnline).length;
    final filtered = filteredCameras.length;
    final systemStatus = onlineCount == total
        ? 'Tất cả camera đang online'
        : '$onlineCount/$total camera đang online';
    final lastUpdated = _state.lastRefreshed == null
        ? 'Chưa đồng bộ'
        : 'Cập nhật ${_formatRelativeTime(_state.lastRefreshed!)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent.shade200, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.shade700.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Camera',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (filtered != total) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Hiển thị $filtered/$total',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              systemStatus,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              lastUpdated,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final filteredCameras = _state.filteredCameras;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Fire-and-forget token fetch for debug
        AuthStorage.getAccessToken()
            .then((token) {
              debugPrint(
                '[LiveCameraHomeScreen] Token when popping to Home: $token',
              );
            })
            .catchError((_) {});
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent.shade100, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text(
            'Camera',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<_CameraHomeMenuOption>(
              tooltip: 'Tùy chọn',
              icon: const Icon(Icons.more_vert),
              onSelected: _onMenuOptionSelected,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _CameraHomeMenuOption.toggleView,
                  child: Row(
                    children: [
                      Icon(
                        _state.grid
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _state.grid
                            ? 'Chuyển sang danh sách'
                            : 'Chuyển sang lưới',
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _CameraHomeMenuOption.toggleSort,
                  child: Row(
                    children: [
                      Icon(
                        _state.sortAsc ? Icons.sort_by_alpha : Icons.sort,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Text(_state.sortAsc ? 'Sắp xếp Z → A' : 'Sắp xếp A → Z'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _CameraHomeMenuOption.refreshThumbnails,
                  enabled: !_state.refreshing,
                  child: Row(
                    children: [
                      Icon(
                        Icons.refresh,
                        color: _state.refreshing
                            ? Colors.black26
                            : Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _state.refreshing
                            ? 'Đang làm mới...'
                            : 'Làm mới ảnh xem trước',
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: _CameraHomeMenuOption.settings,
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.black87),
                      SizedBox(width: 8),
                      Text('Cài đặt'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        // floatingActionButton: _state.cameras.isNotEmpty
        //     ? ScaleTransition(
        //         scale: _fabAnimation,
        //         child: Container(
        //           decoration: BoxDecoration(
        //             gradient: LinearGradient(
        //               colors: [Colors.blueAccent, Colors.blueAccent.shade700],
        //               begin: Alignment.topLeft,
        //               end: Alignment.bottomRight,
        //             ),
        //             borderRadius: BorderRadius.circular(16),
        //             boxShadow: [
        //               BoxShadow(
        //                 color: Colors.blueAccent.withValues(alpha: 0.3),
        //                 blurRadius: 8,
        //                 offset: const Offset(0, 4),
        //               ),
        //             ],
        //           ),
        // child: FloatingActionButton.extended(
        //   backgroundColor: Colors.transparent,
        //   elevation: 0,
        //   onPressed: () {
        //     HapticFeedback.mediumImpact();
        //     _addCamera();
        //   },
        //   icon: const Icon(Icons.add, color: Colors.white, size: 24),
        //   label: const Text(
        //     'Thêm camera',
        //     style: TextStyle(
        //       color: Colors.white,
        //       fontWeight: FontWeight.w600,
        //       fontSize: 14,
        //     ),
        //   ),
        //   shape: RoundedRectangleBorder(
        //     borderRadius: BorderRadius.circular(16),
        //   ),
        // ),
        //     ),
        //   )
        // : null,
        body: Column(
          children: [
            // Camera quota banner
            // CameraQuotaBanner(
            //   quotaValidation: _state.quotaValidation,
            //   onUpgradePressed: _upgradePlan,
            // ),
            // if (_state.cameras.isNotEmpty) _buildSummaryBar(filteredCameras),

            // Main content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _state.loading
                    ? const LoadingView()
                    : _state.cameras.isEmpty
                    ? EmptyView(onAddCamera: _addCamera)
                    : filteredCameras.isEmpty
                    ? NoSearchResultsView(
                        searchQuery: _state.search,
                        onClearSearch: () {
                          if (!mounted) return;
                          _state.updateSearch('');
                        },
                      )
                    : _buildContentView(filteredCameras),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
