import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/repository/event_repository.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import 'package:detect_care_caregiver_app/core/ui/overlay_toast.dart';
import 'package:detect_care_caregiver_app/core/events/app_events.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final EventRepository _repo;
  EventLog? _event;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _repo = EventRepository(
      EventService(
        ApiClient(
          tokenProvider: () async {
            return AuthStorage.getAccessToken();
          },
        ),
      ),
    );

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final e = await _repo.getEventDetails(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = e;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showProposeDialog() async {
    final reasonCtrl = TextEditingController();
    String? selectedStatus;
    DateTime? deadline;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đề xuất thay đổi trạng thái',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái mới',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'normal',
                      child: Text('Bình thường'),
                    ),
                    DropdownMenuItem(value: 'warning', child: Text('Cảnh báo')),
                    DropdownMenuItem(value: 'danger', child: Text('Nguy hiểm')),
                  ],
                  onChanged: (v) => setState(() => selectedStatus = v),
                  value: selectedStatus,
                ),

                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lý do (tùy chọn)',
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Thời hạn duyệt:'),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        deadline == null
                            ? 'Mặc định 24h'
                            : DateFormat('dd/MM/yyyy HH:mm').format(deadline!),
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 7)),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 12, minute: 0),
                          );
                          if (pickedTime != null) {
                            final dt = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            setState(() => deadline = dt);
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Gửi đề xuất'),
                    onPressed: () async {
                      if (selectedStatus == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng chọn trạng thái mới'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      await _sendProposal(
                        selectedStatus!,
                        reasonCtrl.text.trim(),
                        deadline,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleConfirm(bool newValue) async {
    final messenger = ScaffoldMessenger.of(context);
    final ds = EventsRemoteDataSource();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận hành động'),
          content: Text(
            newValue
                ? 'Bạn có muốn đánh dấu sự kiện này là đã xử lý không?'
                : 'Bạn có muốn bỏ đánh dấu đã xử lý cho sự kiện này không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      );

      if (newValue != true) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Không thể bỏ đánh dấu từ màn hình này.'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }

      if (ok != true) return;

      await ds.confirmEvent(
        eventId: widget.eventId,
        confirmStatusBool: true,
        notes: null,
      );
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Đã đánh dấu là đã xử lý'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      try {
        AppEvents.instance.notifyEventsChanged();
      } catch (_) {}
      await _load();
    } catch (e) {
      final raw = e.toString();
      final cleaned = raw.startsWith('Exception: ')
          ? raw.replaceFirst('Exception: ', '')
          : raw;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xác nhận: $cleaned'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _sendProposal(
    String newStatus,
    String reason,
    DateTime? deadline,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (widget.eventId.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ID sự kiện không hợp lệ.')),
      );
      return;
    }
    try {
      dev.log('📤 Sending proposal: $newStatus');
      final updated = await _repo.proposeEvent(
        eventId: widget.eventId,
        proposedStatus: newStatus,
        reason: reason.isEmpty ? null : reason,
        pendingUntil: deadline,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('✅ Gửi đề xuất thành công')),
      );
      try {
        showOverlayToast('✅ Gửi đề xuất thành công');
      } catch (_) {}
      setState(() {
        _event = updated;
      });
    } catch (e) {
      final raw = e.toString();
      final cleaned = raw.startsWith('Exception: ')
          ? raw.replaceFirst('Exception: ', '')
          : raw;
      messenger.showSnackBar(
        SnackBar(content: Text('❌ Gửi đề xuất thất bại: $cleaned')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết sự kiện')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Lỗi tải dữ liệu: $_error'))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: _event == null
                    ? const Center(child: Text('Không tìm thấy dữ liệu'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mã sự kiện: ${_event?.eventId ?? '-'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Loại: ${_event?.eventType ?? '-'}'),
                          const SizedBox(height: 8),
                          Text('Trạng thái hiện tại: ${_event?.status ?? '-'}'),
                          const SizedBox(height: 8),
                          Text(
                            'Mức độ tin cậy: ${_event?.confidenceScore.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (ctx) {
                              String cam = '-';
                              final det = _event?.detectionData ?? {};
                              final ctxData = _event?.contextData ?? {};
                              dynamic first(Map m, List<String> keys) {
                                for (final k in keys) {
                                  if (m.containsKey(k) && m[k] != null) {
                                    return m[k];
                                  }
                                }
                                return null;
                              }

                              final possible = [
                                first(det, [
                                  'camera_id',
                                  'cameraId',
                                  'source',
                                  'device_id',
                                ]),
                                first(ctxData, [
                                  'camera_id',
                                  'cameraId',
                                  'source',
                                  'device_id',
                                ]),
                              ];
                              for (final p in possible) {
                                if (p != null) {
                                  cam = p.toString();
                                  break;
                                }
                              }
                              return Text('Camera: $cam');
                            },
                          ),
                          const SizedBox(height: 8),
                          Text('Mô tả: ${_event?.eventDescription ?? '-'}'),
                          const SizedBox(height: 8),
                          if (_event?.detectedAt != null)
                            Text(
                              'Thời điểm phát hiện: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(_event!.detectedAt!.toLocal())}',
                            ),
                          const SizedBox(height: 24),

                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit_note_rounded),
                              label: const Text('Đề xuất thay đổi trạng thái'),
                              onPressed: _showProposeDialog,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (_event != null)
                            _buildConfirmTile(_event!.confirmStatus),
                        ],
                      ),
              ),
            ),
    );
  }

  Widget _buildConfirmTile(bool confirmed) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SwitchListTile(
        title: const Text('Đánh dấu đã xử lý'),
        subtitle: Text(
          confirmed ? 'Sự kiện đã được đánh dấu' : 'Chưa được đánh dấu',
        ),
        value: confirmed,
        onChanged: confirmed ? null : (v) => _toggleConfirm(v),
      ),
    );
  }
}
