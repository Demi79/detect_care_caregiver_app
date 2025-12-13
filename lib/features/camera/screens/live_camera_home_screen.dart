import 'dart:async';

import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/core/camera_stream_helper.dart';
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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  }

  Future<void> _precacheThumbnails(int limit) async {
    final validUrls = _state.cameras
        .map((c) => c.thumb)
        .where((url) => url != null && url.startsWith('http'))
        .take(limit);

    for (final url in validUrls) {
      try {
        await precacheImage(NetworkImage(url!), context);
      } catch (e) {
        debugPrint('Precache failed for $url: $e');
      }
    }
  }

  @override
  void dispose() {
    _state.removeListener(_stateListener);
    _state.dispose();
    super.dispose();
  }

  Future<void> _playCamera(CameraEntry camera) async {
    if (!mounted) return;

    final playUrl = CameraStreamHelper.getBestUrl(camera) ?? '';

    AppLogger.api(
      '▶️ Mở LiveCameraScreen với cameraId=${camera.id}, playUrl=$playUrl',
    );

    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => LiveCameraScreen(
          initialUrl: playUrl,
          loadCache: false,
          camera: camera,
        ),
        settings: const RouteSettings(name: 'live_camera_screen'),
      ),
    );

    if (mounted) {
      if (result != null) {
        debugPrint('[LiveCameraHomeScreen] Snapshot taken: $result');
      }
      // Chỉ refresh thumbnail của camera vừa xem thay vì tất cả
      await _state.refreshCameraThumb(camera);
    }
  }

  Future<void> _openCameraTimeline(CameraEntry camera) async {
    if (!mounted) return;
    await _state.refreshCameraThumb(camera);
    await Navigator.of(context).push(
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
      case _CameraHomeMenuOption.toggleSort:
        HapticFeedback.selectionClick();
        option == _CameraHomeMenuOption.toggleView
            ? _state.toggleView()
            : _state.toggleSort();
      case _CameraHomeMenuOption.refreshThumbnails:
        if (!_state.refreshing) {
          HapticFeedback.mediumImpact();
          _state.refreshThumbnails();
        }
      case _CameraHomeMenuOption.settings:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cài đặt đang được phát triển.')),
        );
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

    if (!mounted || cameraData == null) return;

    try {
      await _state.updateCamera(camera.id, cameraData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật camera: ${cameraData['camera_name']}'),
          ),
        );
      }
    } catch (e) {
      debugPrint('[API] Error updating camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kDebugMode ? 'Lỗi cập nhật camera: $e' : 'Lỗi cập nhật camera',
            ),
          ),
        );
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

    if (_state.quotaValidation?.canAdd == false) {
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

    if (!mounted || cameraData == null) return;

    try {
      await _state.addCamera(cameraData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm camera: ${cameraData['camera_name']}'),
          ),
        );
      }
    } catch (e) {
      debugPrint('[API] Error creating camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo camera: $e')));
      }
    }
  }

  void _upgradePlan() {
    if (!mounted) return;
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

    if (confirmed != true || !mounted) return;

    try {
      await _state.deleteCamera(camera);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa "${camera.name}"'),
            action: SnackBarAction(
              label: 'Hoàn tác',
              onPressed: () => mounted ? _state.undoDelete(camera.id) : null,
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa camera: $e')));
      }
    }
  }

  void _onSearchChanged(String value) =>
      mounted ? _state.updateSearch(value) : null;

  Widget _buildContentView(List<CameraEntry> cameras) {
    final statusNote = _state.lastRefreshed == null
        ? 'Chưa đồng bộ'
        : 'Cập nhật ${_formatRelativeTime(_state.lastRefreshed!)}';

    return RefreshIndicator(
      key: const ValueKey('content'),
      color: Colors.blueAccent,
      backgroundColor: Colors.white,
      onRefresh: () async {
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
                    onPlay: _playCamera,
                    onDelete: _confirmAndRemove,
                    onEdit: _editCamera,
                    onRefreshRequested: _state.refreshCameraThumb,
                    onShowTimeline: _openCameraTimeline,
                    searchQuery: _state.search,
                    statusNote: statusNote,
                  )
                : CameraList(
                    cameras: cameras,
                    onPlay: _playCamera,
                    onDelete: _confirmAndRemove,
                    onShowTimeline: _openCameraTimeline,
                    searchQuery: _state.search,
                    statusNote: statusNote,
                  ),
          ),
        ],
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
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _state.loading
              ? const LoadingView()
              : _state.cameras.isEmpty
              ? EmptyView(onAddCamera: _addCamera)
              : filteredCameras.isEmpty
              ? NoSearchResultsView(
                  searchQuery: _state.search,
                  onClearSearch: () => _state.updateSearch(''),
                )
              : _buildContentView(filteredCameras),
        ),
      ),
    );
  }
}
