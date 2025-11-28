import 'dart:async';

import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/live_camera_screen.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_home_state.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_quota_service.dart';
import 'package:detect_care_caregiver_app/features/subscription/data/service_package_api.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_service.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/add_camera_dialog.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/camera_layouts.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/camera_quota_banner.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/camera_views.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/controls_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveCameraHomeScreen extends StatefulWidget {
  const LiveCameraHomeScreen({super.key});

  @override
  State<LiveCameraHomeScreen> createState() => _LiveCameraHomeScreenState();
}

class _LiveCameraHomeScreenState extends State<LiveCameraHomeScreen>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<LiveCameraHomeScreen> {
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('rtsp_url');
    } catch (e) {
      debugPrint('Failed to clear saved RTSP URL: $e');
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) =>
            LiveCameraScreen(initialUrl: camera.url, loadCache: false),
        settings: const RouteSettings(name: 'live_camera_screen'),
      ),
    );

    if (result != null && mounted) {
      debugPrint('[LiveCameraHomeScreen] Snapshot taken: $result');
    }

    if (mounted) {
      await _state.refreshThumbnails();
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

    if (_state.quotaValidation == null) {
      await _state.validateCameraQuota();
      if (!mounted) return;
    }

    if (_state.quotaValidation != null && !_state.quotaValidation!.canAdd) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _state.quotaValidation!.message ?? 'Không thể thêm camera',
          ),
          action: null,
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nâng cấp gói không khả dụng trong ứng dụng này.'),
      ),
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
                    searchQuery: _state.search,
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
                    searchQuery: _state.search,
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final filteredCameras = _state.filteredCameras;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
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

        // appBar: AppBar(
        //   backgroundColor: Colors.white,
        //   elevation: 0,
        //   flexibleSpace: Container(
        //     decoration: BoxDecoration(
        //       gradient: LinearGradient(
        //         colors: [Colors.blueAccent.shade100, Colors.blueAccent],
        //         begin: Alignment.topLeft,
        //         end: Alignment.bottomRight,
        //       ),
        //     ),
        //   ),
        //   title: Text(
        //     'Camera${filteredCameras.isNotEmpty ? ' (${filteredCameras.length})' : ''}',
        //     style: const TextStyle(
        //       color: Colors.white,
        //       fontWeight: FontWeight.bold,
        //       fontSize: 20,
        //       shadows: [
        //         Shadow(
        //           color: Colors.black26,
        //           offset: Offset(0, 1),
        //           blurRadius: 2,
        //         ),
        //       ],
        //     ),
        //   ),
        //   iconTheme: const IconThemeData(color: Colors.white),
        //   actions: [
        //     IconButton(
        //       tooltip: _state.grid ? 'Chuyển danh sách' : 'Chuyển lưới',
        //       onPressed: () {
        //         if (!mounted) return;
        //         HapticFeedback.selectionClick();
        //         _state.toggleView();
        //       },
        //       icon: AnimatedSwitcher(
        //         duration: const Duration(milliseconds: 200),
        //         child: Icon(
        //           _state.grid
        //               ? Icons.view_list_rounded
        //               : Icons.grid_view_rounded,
        //           key: ValueKey(_state.grid),
        //           color: Colors.white,
        //           shadows: const [
        //             Shadow(
        //               color: Colors.black26,
        //               offset: Offset(0, 1),
        //               blurRadius: 2,
        //             ),
        //           ],
        //         ),
        //       ),
        //     ),
        //     IconButton(
        //       tooltip: _state.sortAsc ? 'Sắp xếp Z-A' : 'Sắp xếp A-Z',
        //       onPressed: () {
        //         if (!mounted) return;
        //         HapticFeedback.selectionClick();
        //         _state.toggleSort();
        //       },
        //       icon: AnimatedSwitcher(
        //         duration: const Duration(milliseconds: 200),
        //         child: Icon(
        //           _state.sortAsc ? Icons.sort_by_alpha : Icons.sort,
        //           key: ValueKey(_state.sortAsc),
        //           color: Colors.white,
        //           shadows: const [
        //             Shadow(
        //               color: Colors.black26,
        //               offset: Offset(0, 1),
        //               blurRadius: 2,
        //             ),
        //           ],
        //         ),
        //       ),
        //     ),
        //     IconButton(
        //       tooltip: 'Làm mới ảnh xem trước',
        //       onPressed: _state.refreshing
        //           ? null
        //           : () {
        //               if (!mounted) return;
        //               HapticFeedback.mediumImpact();
        //               _state.refreshThumbnails();
        //             },
        //       icon: AnimatedRotation(
        //         turns: _state.refreshing ? 1.0 : 0.0,
        //         duration: const Duration(seconds: 1),
        //         child: Icon(
        //           Icons.refresh,
        //           color: _state.refreshing ? Colors.white70 : Colors.white,
        //           shadows: const [
        //             Shadow(
        //               color: Colors.black26,
        //               offset: Offset(0, 1),
        //               blurRadius: 2,
        //             ),
        //           ],
        //         ),
        //       ),
        //     ),
        //   ],
        // ),
        floatingActionButton: _state.cameras.isNotEmpty
            ? ScaleTransition(
                scale: _fabAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blueAccent, Colors.blueAccent.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton.extended(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _addCamera();
                    },
                    icon: const Icon(Icons.add, color: Colors.white, size: 24),
                    label: const Text(
                      'Thêm camera',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              )
            : null,
        body: Column(
          children: [
            CameraQuotaBanner(
              quotaValidation: _state.quotaValidation,
              onUpgradePressed: null,
            ),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _state.loading
                    ? const LoadingView()
                    : _state.cameras.isEmpty
                    ? const EmptyView()
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
