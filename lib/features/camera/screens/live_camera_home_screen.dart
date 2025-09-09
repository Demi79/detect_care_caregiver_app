import 'dart:async';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_api.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/add_camera_dialog.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/camera_card.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/camera_stats_row.dart';
import 'package:flutter/material.dart';

import 'live_camera_screen.dart';

class LiveCameraHomeScreen extends StatefulWidget {
  const LiveCameraHomeScreen({super.key});
  @override
  State<LiveCameraHomeScreen> createState() => _LiveCameraHomeScreenState();
}

class _LiveCameraHomeScreenState extends State<LiveCameraHomeScreen> {
  Future<void> _showCameraDetail(CameraEntry camera) async {
    final detail = await _cameraApi.getCameraDetail(camera.id);
    final events = await _cameraApi.getCameraEvents(camera.id);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Chi tiết Camera'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${detail.id}'),
              Text('Tên: ${detail.name}'),
              Text('URL: ${detail.url}'),
              const SizedBox(height: 12),
              Text('Events:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(((events['data'] as List?) ?? []).map(
                (e) => Text(e.toString()),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  List<CameraEntry> _cameras = [];
  bool _loading = true;
  final Duration _thumbRefreshInterval = const Duration(hours: 4);
  Timer? _thumbTimer;
  // UI state
  bool _grid = true;
  bool _sortAsc = true;
  String _search = '';
  DateTime? _lastRefreshed;
  late CameraApi _cameraApi;

  @override
  void initState() {
    super.initState();
    _cameraApi = CameraApi(
      ApiClient(tokenProvider: AuthStorage.getAccessToken),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final userId = await AuthStorage.getUserId();
      final result = await _cameraApi.getCamerasByUser(userId: userId ?? '');
      final List<dynamic> data = result['data'] ?? [];
      final list = data.map((e) => CameraEntry.fromJson(e)).toList();
      if (!mounted) return;
      setState(() {
        _cameras = List<CameraEntry>.from(list);
        _loading = false;
        _lastRefreshed = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameras = [];
        _loading = false;
      });
    }
    _scheduleThumbRefresh();
  }

  Future<void> _play(CameraEntry c) async {
    if (!mounted) return;
    debugPrint(
      '[LiveCameraHomeScreen] Đang mở LiveCameraScreen cho: ${c.name}',
    );
    await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => LiveCameraScreen(initialUrl: c.url),
        settings: const RouteSettings(name: 'live_camera_screen'),
      ),
    );
  }

  Future<void> _addCamera() async {
    final userId = await AuthStorage.getUserId();
    if (!mounted) return;
    final cameraData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AddCameraDialog(userId: userId),
    );
    if (!mounted) return;
    debugPrint('[ADD CAMERA] userId: $userId, cameraData: $cameraData');
    if (cameraData != null) {
      try {
        final res = await _cameraApi.createCamera(cameraData);
        debugPrint('[API] Tạo camera response: $res');
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm camera: ${res['camera_name'] ?? ''}'),
          ),
        );
      } catch (e) {
        debugPrint('[API] Lỗi tạo camera: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo camera: $e')));
      }
    } else {
      debugPrint('[ADD CAMERA] Không có dữ liệu camera mới');
    }
  }

  Future<void> _remove(CameraEntry c) async {
    debugPrint('[REMOVE CAMERA] id: ${c.id}, name: ${c.name}');
    try {
      await _cameraApi.deleteCamera(c.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã xóa camera: ${c.name}')));
    } catch (e) {
      debugPrint('[REMOVE CAMERA] Lỗi xóa camera: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi xóa camera: $e')));
    }
  }

  void _scheduleThumbRefresh() {
    _thumbTimer?.cancel();
    _thumbTimer = Timer.periodic(
      _thumbRefreshInterval,
      (_) => _refreshAllThumbs(),
    );
  }

  @override
  void dispose() {
    _thumbTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAllThumbs() async {
    if (!mounted) return;
    setState(() {
      _cameras = _cameras
          .map(
            (c) => CameraEntry(
              id: c.id,
              name: c.name,
              url: c.url,
              thumb: _cacheBustThumb(c.thumb),
              isOnline: c.isOnline,
            ),
          )
          .toList();
      _lastRefreshed = DateTime.now();
    });
  }

  void _refreshThumb(CameraEntry c) {
    setState(() {
      final i = _cameras.indexOf(c);
      if (i >= 0) {
        final old = _cameras[i];
        _cameras[i] = CameraEntry(
          id: old.id,
          name: old.name,
          url: old.url,
          thumb: _cacheBustThumb(old.thumb),
          isOnline: old.isOnline,
        );
      }
    });
  }

  String? _cacheBustThumb(String? t) {
    if (t == null || t.isEmpty || !t.startsWith('http')) return t;
    final uri = Uri.parse(t);
    final qp = Map<String, String>.from(uri.queryParameters);
    qp['t'] = DateTime.now().millisecondsSinceEpoch.toString();
    return uri.replace(queryParameters: qp).toString();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredSorted(_cameras);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: Text('Camera${items.isNotEmpty ? ' (${items.length})' : ''}'),
        actions: [
          IconButton(
            tooltip: _grid ? 'Chuyển danh sách' : 'Chuyển lưới',
            onPressed: () => setState(() => _grid = !_grid),
            icon: Icon(
              _grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
          ),
          IconButton(
            tooltip: _sortAsc ? 'Sắp xếp Z-A' : 'Sắp xếp A-Z',
            onPressed: () => setState(() => _sortAsc = !_sortAsc),
            icon: Icon(_sortAsc ? Icons.sort_by_alpha : Icons.sort),
          ),
          IconButton(
            tooltip: 'Làm mới ảnh xem trước',
            onPressed: _refreshAllThumbs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCamera,
        icon: const Icon(Icons.add),
        label: const Text('Thêm camera'),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _cameras.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off, size: 64, color: Colors.black26),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có camera nào',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhấn nút + để thêm camera mới',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _addCamera,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm camera'),
                    ),
                  ],
                ),
              )
            : items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.black26),
                    const SizedBox(height: 16),
                    Text(
                      'Không có camera nào khớp với tìm kiếm.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await _load();
                  await _refreshAllThumbs();
                },
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: CameraStatsRow(
                          abnormalCount: 0,
                          offlineCount: 0,
                          noStorageCount: 0,
                          loading: false,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _ControlsBar(
                        search: _search,
                        onSearchChanged: (v) => setState(() => _search = v),
                        lastRefreshed: _lastRefreshed,
                        total: _cameras.length,
                        filtered: items.length,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      sliver: _grid ? _buildGrid(items) : _buildList(items),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  List<CameraEntry> _filteredSorted(List<CameraEntry> data) {
    var list = data;
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
    list.sort((a, b) {
      final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  Widget _buildList(List<CameraEntry> items) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, i) {
        final c = items[i];
        return AnimatedSlide(
          offset: Offset(0, 0),
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: CameraCard(
              key: ValueKey(c.url),
              camera: c,
              onPlay: _play,
              onDelete: (cam) async {
                debugPrint(
                  '[UI DELETE] Camera id: ${cam.id}, name: ${cam.name}',
                );
                try {
                  await _cameraApi.deleteCamera(cam.id);
                  debugPrint('[API DELETE] Done');
                  await _load();
                  debugPrint('[UI DELETE] Reloaded camera list');
                } catch (e) {
                  debugPrint('[API DELETE] Error: $e');
                }
              },
              onEdit: (cam) => _showCameraDetail(cam),
              onRefreshRequested: () => _refreshThumb(c),
              headerLabel: null,
              isGrid2: false,
            ),
          ),
        );
      }, childCount: items.length),
    );
  }

  Widget _buildGrid(List<CameraEntry> items) {
    final crossAxisCount = 2;
    final aspectRatio = MediaQuery.of(context).size.width < 600 ? 0.75 : 1.1;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final c = items[i];
        return CameraCard(
          key: ValueKey(c.url),
          camera: c,
          onPlay: _play,
          onDelete: _remove,
          onRefreshRequested: () => _refreshThumb(c),
          headerLabel: null,
          isGrid2: true,
          height: 250,
        );
      }, childCount: items.length),
    );
  }
}

class _ControlsBar extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final DateTime? lastRefreshed;
  final int total;
  final int filtered;

  const _ControlsBar({
    required this.search,
    required this.onSearchChanged,
    required this.lastRefreshed,
    required this.total,
    required this.filtered,
  });

  @override
  Widget build(BuildContext context) {
    final text = TextEditingController(text: search);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: text,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Tìm camera theo tên...',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _LastUpdatedBadge(lastRefreshed: lastRefreshed),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              filtered == total
                  ? 'Tổng: $total camera'
                  : 'Hiển thị $filtered / $total camera',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastUpdatedBadge extends StatelessWidget {
  final DateTime? lastRefreshed;
  const _LastUpdatedBadge({required this.lastRefreshed});

  @override
  Widget build(BuildContext context) {
    final txt = lastRefreshed == null
        ? '—'
        : '${lastRefreshed!.hour.toString().padLeft(2, '0')}:${lastRefreshed!.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text('Cập nhật: $txt', style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
