import 'dart:async';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart';
import 'package:detect_care_caregiver_app/features/alarm/services/active_alarm_notifier.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_api.dart';
import 'package:detect_care_caregiver_app/features/camera/screens/live_camera_screen.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/home/repository/event_repository.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_log.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final bool openedFromFCM;
  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.openedFromFCM = false,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final EventRepository _repo;
  EventLog? _event;
  bool _loading = true;
  String? _error;

  Timer? _timer;
  Duration _remaining = Duration.zero;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    _repo = EventRepository(
      EventService(
        ApiClient(tokenProvider: () async => AuthStorage.getAccessToken()),
      ),
    );
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final evt = await _repo.getEventDetails(widget.eventId);
      _event = evt;
      // Update alarm active notifier from server lifecycle so UI buttons update
      try {
        final lifecycle = (evt.lifecycleState ?? '').toString().toUpperCase();
        ActiveAlarmNotifier.instance.update(lifecycle == 'ALARM_ACTIVATED');
      } catch (_) {}

      _deadline =
          evt.pendingUntil ??
          DateTime.now().toUtc().add(const Duration(days: 1));
      if (_isPendingReview) _startCountdown();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool get _isPendingReview {
    if (_event == null) return false;
    final e = _event!;
    final hasProposal =
        e.proposedStatus != null && e.proposedStatus!.isNotEmpty;
    final waiting = e.confirmationState == 'CAREGIVER_UPDATED';
    return hasProposal && waiting;
  }

  void _startCountdown() {
    _timer?.cancel();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now().toUtc();
    final dl = _deadline ?? now;
    final diff = dl.difference(now);
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  String _fmtDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    final secs = d.inSeconds % 60;
    if (days > 0) return '${days}d ${hours}h ${mins}m ${secs}s';
    if (hours > 0) return '${hours}h ${mins}m ${secs}s';
    return '${mins}m ${secs}s';
  }

  String _viStatus(String raw) => BackendEnums.statusToVietnamese(raw);
  String _viEventType(String raw) => BackendEnums.eventTypeToVietnamese(raw);

  Color _statusColor(String raw) =>
      AppTheme.getStatusColor(raw.trim().toLowerCase());

  IconData _statusIcon(String raw) {
    final s = raw.trim().toLowerCase();
    switch (s) {
      case 'danger':
      case 'critical':
      case 'emergency':
        return Icons.dangerous_rounded;
      case 'warning':
        return Icons.warning_rounded;
      case 'normal':
        return Icons.check_circle_rounded;
      case 'abnormal':
      case 'suspect':
        return Icons.error_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  IconData _eventTypeIcon(String raw) {
    final t = raw.trim().toLowerCase();
    switch (t) {
      case 'fall':
        return Icons.person_off_rounded;
      case 'abnormal_behavior':
        return Icons.psychology_alt_rounded;
      case 'emergency':
        return Icons.emergency_rounded;
      case 'normal_activity':
        return Icons.directions_walk_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      default:
        return Icons.category_outlined;
    }
  }

  Widget _pill({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sự kiện')),
        body: Center(child: Text('Lỗi: $_error')),
      );
    }

    final e = _event!;
    final statusColor = _statusColor(e.status);
    final statusText = _viStatus(e.status);
    final typeText = _viEventType(e.eventType);
    // final confidence = e.confidenceScore;
    // final confidencePctRaw = (confidence <= 1.0)
    //     ? (confidence * 100)
    //     : confidence;
    // final confidencePct = confidencePctRaw.clamp(0, 100).toDouble();
    // final confidenceLabel = '${confidencePct.toStringAsFixed(0)}%';

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết sự kiện')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            typeText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _pill(
                          color: statusColor,
                          icon: _statusIcon(e.status),
                          text: statusText,
                        ),
                      ],
                    ),
                    if ((e.eventDescription ?? '').trim().isNotEmpty &&
                        (e.eventDescription ?? '').trim().toLowerCase() !=
                            e.eventType.trim().toLowerCase()) ...[
                      const SizedBox(height: 6),
                      Text(
                        e.eventDescription!.trim(),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _detailRow(
                            icon: _eventTypeIcon(e.eventType),
                            label: 'Loại sự kiện',
                            child: _pill(
                              color: Theme.of(context).colorScheme.primary,
                              icon: _eventTypeIcon(e.eventType),
                              text: typeText,
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey.shade200),
                          _detailRow(
                            icon: Icons.timeline_outlined,
                            label: 'Trạng thái hiện tại',
                            child: _pill(
                              color: statusColor,
                              icon: _statusIcon(e.status),
                              text: statusText,
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey.shade200),
                          // _detailRow(
                          //   icon: Icons.verified_outlined,
                          //   label: 'Độ tin cậy',
                          //   child: Column(
                          //     crossAxisAlignment: CrossAxisAlignment.start,
                          //     children: [
                          //       Text(
                          //         confidenceLabel,
                          //         style: const TextStyle(
                          //           fontWeight: FontWeight.w700,
                          //         ),
                          //       ),
                          //       const SizedBox(height: 6),
                          //       ClipRRect(
                          //         borderRadius: BorderRadius.circular(999),
                          //         child: LinearProgressIndicator(
                          //           value: confidencePct / 100.0,
                          //           minHeight: 8,
                          //           backgroundColor: statusColor.withValues(
                          //             alpha: 0.12,
                          //           ),
                          //           valueColor: AlwaysStoppedAnimation<Color>(
                          //             statusColor,
                          //           ),
                          //         ),
                          //       ),
                          //     ],
                          //   ),
                          // ),
                          if (e.detectedAt != null) ...[
                            Divider(height: 1, color: Colors.grey.shade200),
                            _detailRow(
                              icon: Icons.schedule_outlined,
                              label: 'Thời gian phát hiện',
                              child: Text(
                                DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(e.detectedAt!.toLocal()),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (e.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Ảnh liên quan',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: e.imageUrls.length,
                  itemBuilder: (context, index) {
                    final url = e.imageUrls[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _ImageGalleryPage(
                                images: e.imageUrls,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 220,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 220,
                              height: 160,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (e.pendingReason != null && e.pendingReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _detailRow(
                    icon: Icons.notes_outlined,
                    label: 'Lý do chờ duyệt',
                    child: Text(
                      e.pendingReason!.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
            if (_isPendingReview) ...[
              const SizedBox(height: 8),
              _proposalBlock(e),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (e.cameraId != null && e.cameraId!.isNotEmpty)
            SafeArea(
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _openLiveView(e.cameraId!),
                    icon: const Icon(Icons.videocam_outlined, size: 20),
                    label: Text(
                      (e.status.trim().toLowerCase() == 'danger' ||
                              e.status.trim().toLowerCase() == 'emergency')
                          ? 'XEM TRỰC TIẾP NGAY'
                          : 'XEM CAMERA',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (e.status.trim().toLowerCase() == 'danger' ||
                              e.status.trim().toLowerCase() == 'emergency')
                          ? Colors.red.shade600
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          _buildBottomAction(e),
        ],
      ),
    );
  }

  Future<void> _openLiveView(String cameraId) async {
    try {
      final api = CameraApi(
        ApiClient(tokenProvider: () async => AuthStorage.getAccessToken()),
      );
      final camera = await api.getCameraDetail(cameraId);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiveCameraScreen(camera: camera)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở camera trực tiếp: $e')),
        );
      }
    }
  }

  Widget _proposalBlock(EventLog e) {
    final deadlineLocal =
        (_deadline ?? DateTime.now().toUtc().add(const Duration(days: 1)))
            .toLocal();
    final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(deadlineLocal);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pending_outlined, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              const Text(
                'Caregiver đề xuất thay đổi',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _detailRow(
            icon: Icons.edit_outlined,
            label: 'Trạng thái đề xuất',
            child: Text(
              e.proposedStatus == null || e.proposedStatus!.trim().isEmpty
                  ? '-'
                  : _viStatus(e.proposedStatus!),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (e.previousStatus != null)
            _detailRow(
              icon: Icons.history_outlined,
              label: 'Trạng thái trước đó',
              child: Text(
                _viStatus(e.previousStatus!),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          if (e.proposedEventType != null)
            _detailRow(
              icon: Icons.category_outlined,
              label: 'Loại sự kiện mới',
              child: Text(
                _viEventType(e.proposedEventType!),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer, size: 18),
              const SizedBox(width: 6),
              Text(
                'Tự động chấp nhận sau: ${_fmtDuration(_remaining)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(
            'Hạn duyệt: $timeStr',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            'Nếu bạn không phản hồi trước thời hạn, hệ thống sẽ tự động chấp nhận đề xuất.',
            style: TextStyle(color: Colors.amber.shade800, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(EventLog e) {
    // Nếu event không chờ duyệt → hiện nút cập nhật + nút xóa
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Xóa sự kiện',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade600),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.white,
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Xác nhận xóa'),
                    content: const Text('Bạn có chắc muốn xóa sự kiện này?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hủy'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Xóa'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;

                final reasonCtl = TextEditingController();
                final provideReason = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Lý do (tùy chọn)'),
                    content: TextField(
                      controller: reasonCtl,
                      decoration: const InputDecoration(
                        hintText: 'Nhập lý do xóa (tùy chọn)',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Bỏ qua'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Gửi'),
                      ),
                    ],
                  ),
                );

                // Call backend cancel endpoint
                try {
                  await EventsRemoteDataSource().cancelEvent(
                    eventId: e.eventId,
                    reason: provideReason == true
                        ? reasonCtl.text
                        : 'Xóa bởi khách hàng',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Sự kiện đã được xóa.'),
                      backgroundColor: Colors.green[700],
                    ),
                  );
                  await _load();
                } catch (err) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Xóa thất bại: $err'),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Đề xuất sự kiện'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final changed = await Navigator.pushNamed<bool?>(
                  context,
                  '/update-event',
                  arguments: e,
                );
                if (changed == true) {
                  await _load();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageGalleryPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _ImageGalleryPage({required this.images, this.initialIndex = 0});

  @override
  State<_ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<_ImageGalleryPage> {
  late PageController _pc;
  late int _pageIndex;

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pc = PageController(initialPage: _pageIndex);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${_pageIndex + 1}/${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _pageIndex = i),
        itemBuilder: (context, i) {
          final url = widget.images[i];
          return Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
