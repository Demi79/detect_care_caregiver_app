import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/features/home/repository/event_repository.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_images_loader.dart';
import 'package:detect_care_caregiver_app/features/home/widgets/action_log_card_image_viewer_helper.dart';
import '../../../core/utils/backend_enums.dart' as be;
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/core/utils/logger.dart';

class ProposeScreen extends StatefulWidget {
  final LogEntry logEntry;
  const ProposeScreen({super.key, required this.logEntry});

  @override
  State<ProposeScreen> createState() => _ProposeScreenState();
}

class _ProposeScreenState extends State<ProposeScreen> {
  final _noteCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;
  bool _loading = false;

  bool _isDelete = false;

  String? _selectedStatus;
  String? _selectedEventType;

  late final EventRepository _repo;
  static const Duration _kEventUpdateWindow = Duration(days: 2);
  late final EventLog eventForImages;
  late final Future<List<String>> imagesFuture;
  int highlightedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _repo = EventRepository(EventService.withDefaultClient());
    eventForImages = EventLog(
      eventId: widget.logEntry.eventId,
      status: widget.logEntry.status,
      eventType: widget.logEntry.eventType,
      eventDescription: widget.logEntry.eventDescription,
      confidenceScore: widget.logEntry.confidenceScore,
      detectedAt: widget.logEntry.detectedAt,
      createdAt: widget.logEntry.createdAt,
      detectionData: widget.logEntry.detectionData,
      aiAnalysisResult: widget.logEntry.aiAnalysisResult,
      contextData: widget.logEntry.contextData,
      boundingBoxes: widget.logEntry.boundingBoxes,
      confirmStatus: widget.logEntry.confirmStatus,
      imageUrls: const [],
      lifecycleState: widget.logEntry.lifecycleState,
      cameraId: widget.logEntry.cameraId,
    );
    imagesFuture = loadEventImageUrls(eventForImages);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _showImagesModal(
    BuildContext pageContext,
    EventLog event,
  ) async {
    try {
      final urls = await loadEventImageUrls(event);
      if (urls.isEmpty) {
        await showDialog<void>(
          context: pageContext,
          builder: (ctx) => AlertDialog(
            title: const Text('Hình ảnh'),
            content: const Text('Không có ảnh để hiển thị.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
        return;
      }
      final index = highlightedImageIndex.clamp(0, urls.length - 1);
      return showActionLogCardImageViewer(pageContext, urls, index);
    } catch (e) {
      debugPrint('[ProposeScreen] _showImagesModal error: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) setState(() => _pickedImage = File(picked.path));
    } catch (e) {
      debugPrint('[PROPOSE] Image pick failed: $e');
    }
  }

  Future<void> _submit() async {
    AppLogger.d(
      '[ProposeScreen] _submit called - isDelete=$_isDelete eventId=${widget.logEntry.eventId}',
    );

    // Validation
    if (_isDelete) {
      // Chỉ cần lý do khi xóa
      if (_noteCtrl.text.trim().isEmpty) {
        AppLogger.w(
          '[ProposeScreen] Validation failed: empty reason for delete',
        );
        _showErrorSnackBar('Vui lòng nhập lý do đề xuất xóa');
        return;
      }
      AppLogger.d('[ProposeScreen] Delete mode validation passed');
    } else {
      // Khi cập nhật, cần chọn ít nhất một thay đổi
      if (_selectedStatus == null && _selectedEventType == null) {
        AppLogger.w(
          '[ProposeScreen] Validation failed: no status or event type selected',
        );
        _showErrorSnackBar('Vui lòng chọn trạng thái hoặc loại sự kiện');
        return;
      }
      if (_noteCtrl.text.trim().isEmpty) {
        AppLogger.w('[ProposeScreen] Validation failed: empty reason');
        _showErrorSnackBar('Vui lòng nhập lý do đề xuất');
        return;
      }
      AppLogger.d(
        '[ProposeScreen] Update mode validation passed - status=$_selectedStatus type=$_selectedEventType',
      );
    }

    setState(() => _loading = true);
    AppLogger.i('[ProposeScreen] Submit started - loading state set to true');

    try {
      // Kiểm tra xem sự kiện có đang có đề xuất chờ duyệt không
      try {
        AppLogger.d(
          '[ProposeScreen] Checking for existing pending proposals...',
        );
        final current = await _repo.getEventDetails(widget.logEntry.eventId);
        if (current.proposedStatus != null &&
            (current.pendingUntil != null &&
                current.pendingUntil!.isAfter(DateTime.now()))) {
          AppLogger.w(
            '[ProposeScreen] Event already has pending proposal - proposedStatus=${current.proposedStatus} pendingUntil=${current.pendingUntil}',
          );
          _showErrorSnackBar('Sự kiện đang có đề xuất chờ duyệt.');
          setState(() => _loading = false);
          return;
        }
        AppLogger.d(
          '[ProposeScreen] No pending proposals found, proceeding...',
        );
      } catch (e) {
        AppLogger.e(
          '[ProposeScreen] Failed to fetch event details pre-check: $e',
          e,
        );
      }

      final pendingUntil = DateTime.now().add(const Duration(hours: 48));
      AppLogger.d(
        '[ProposeScreen] Pending until: ${pendingUntil.toIso8601String()}',
      );

      if (_isDelete) {
        AppLogger.i(
          '[ProposeScreen] Calling proposeDeleteEvent - eventId=${widget.logEntry.eventId} reasonLength=${_noteCtrl.text.trim().length}',
        );
        await _repo.proposeDeleteEvent(
          eventId: widget.logEntry.eventId,
          reason: _noteCtrl.text.trim(),
          pendingUntil: pendingUntil,
        );
        AppLogger.i(
          '[ProposeScreen] proposeDeleteEvent completed successfully',
        );
      } else {
        AppLogger.i(
          '[ProposeScreen] Calling proposeEvent - eventId=${widget.logEntry.eventId} status=$_selectedStatus type=$_selectedEventType reasonLength=${_noteCtrl.text.trim().length}',
        );
        await _repo.proposeEvent(
          eventId: widget.logEntry.eventId,
          proposedStatus: _selectedStatus ?? widget.logEntry.status,
          proposedEventType: _selectedEventType,
          reason: _noteCtrl.text.trim(),
          pendingUntil: pendingUntil,
        );
        AppLogger.i('[ProposeScreen] proposeEvent completed successfully');
      }

      try {
        AppLogger.d('[ProposeScreen] Broadcasting events changed notification');
        AppEvents.instance.notifyEventsChanged();
      } catch (e) {
        AppLogger.e('[ProposeScreen] Failed to notify events changed: $e', e);
      }

      AppLogger.i('[ProposeScreen] Proposal submitted successfully');
      _showSuccessSnackBar('Đã gửi đề xuất thành công');

      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        AppLogger.d('[ProposeScreen] Navigating back to home after success');
        try {
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
        } catch (e) {
          AppLogger.e('[ProposeScreen] Failed to pop to root: $e', e);
          Navigator.pop(context);
        }
      }
    } catch (e, st) {
      AppLogger.e('[ProposeScreen] Proposal submission failed: $e', e, st);
      _showErrorSnackBar('Gửi đề xuất thất bại: $e');
    } finally {
      if (mounted) {
        AppLogger.d('[ProposeScreen] Resetting loading state');
        setState(() => _loading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  Widget _buildCurrentInfoCard() {
    final data = widget.logEntry;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.getStatusColor(data.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.getStatusColor(data.status),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Thông tin hiện tại',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Trạng thái: ',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    Text(
                      be.BackendEnums.statusToVietnamese(data.status),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getStatusColor(data.status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Loại sự kiện: ',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    Text(
                      be.BackendEnums.eventTypeToVietnamese(data.eventType),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.lock_clock, color: Colors.orange.shade600, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đề xuất chỉ khả dụng trong vòng ${_kEventUpdateWindow.inDays} ngày kể từ khi sự kiện được ghi nhận.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<String>>(
            future: imagesFuture,
            builder: (context, snapshot) {
              Widget preview;
              if (snapshot.connectionState != ConnectionState.done) {
                preview = Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                preview = Container(
                  height: 120,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'Lỗi tải ảnh: ${snapshot.error}',
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  ),
                );
              } else {
                final urls = snapshot.data ?? const [];
                if (urls.isEmpty) {
                  preview = Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'Chưa có ảnh liên quan.\nHệ thống sẽ hiển thị ngay khi ảnh có thể tải được.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                } else {
                  final previewIndex = highlightedImageIndex.clamp(
                    0,
                    urls.length - 1,
                  );
                  preview = SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final url = urls[index];
                        final isSelected = index == previewIndex;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => highlightedImageIndex = index),
                          child: Container(
                            width: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade200,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      loadingBuilder:
                                          (
                                            context,
                                            child,
                                            progress,
                                          ) => progress == null
                                          ? child
                                          : const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                      errorBuilder: (context, error, stack) =>
                                          Container(
                                            color: Colors.grey.shade100,
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Material(
                                      color: Colors.white.withOpacity(0.7),
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () =>
                                            showActionLogCardImageViewer(
                                              context,
                                              urls,
                                              index,
                                            ),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.zoom_in,
                                            size: 18,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemCount: urls.length,
                    ),
                  );
                }
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  preview,
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          _showImagesModal(context, eventForImages),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Xem ảnh chi tiết'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: Colors.amber.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Lý do đề xuất (bắt buộc)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            maxLines: 5,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: _isDelete
                  ? 'Vì sao bạn muốn xóa sự kiện này? (VD: Phát hiện sai, không liên quan...)'
                  : 'Nhập lý do chi tiết cho đề xuất thay đổi của bạn...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _isDelete
                      ? Colors.red.shade400
                      : const Color(0xFF3B82F6),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelectionCard() {
    if (_isDelete) return const SizedBox.shrink();

    final data = widget.logEntry;
    final allStatusOptions = [
      'danger',
      'warning',
      'normal',
      'unknown',
      'suspect',
      'abnormal',
    ];
    final statusLabels = {
      'danger': 'Nguy hiểm',
      'warning': 'Cảnh báo',
      'normal': 'Bình thường',
      'unknown': 'Không xác định',
      'suspect': 'Đáng ngờ',
      'abnormal': 'Bất thường',
    };

    final statusColors = {
      'danger': Colors.red.shade600,
      'warning': Colors.orange.shade600,
      'normal': Colors.green.shade600,
      'unknown': Colors.grey.shade600,
      'suspect': Colors.purple.shade600,
      'abnormal': Colors.amber.shade700,
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.flag_outlined,
                  color: Colors.purple.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Đề xuất trạng thái mới',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: allStatusOptions
                .where((s) => s != data.status.toLowerCase())
                .map(
                  (s) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selectedStatus = s),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedStatus == s
                              ? statusColors[s]
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedStatus == s
                                ? statusColors[s]!
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedStatus == s)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            Text(
                              statusLabels[s]!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedStatus == s
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: _selectedStatus == s
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTypeSelectionCard() {
    if (_isDelete) return const SizedBox.shrink();

    final data = widget.logEntry;
    final availableEventTypes = [
      'fall',
      'abnormal_behavior',
      'emergency',
      'normal_activity',
      'sleep',
    ].where((t) => t != data.eventType).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.category_outlined,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Đề xuất loại sự kiện mới',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: availableEventTypes
                .map(
                  (type) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selectedEventType = type),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedEventType == type
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedEventType == type
                                ? const Color(0xFF3B82F6)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedEventType == type)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            Text(
                              be.BackendEnums.eventTypeToVietnamese(type),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedEventType == type
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: _selectedEventType == type
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDelete ? Colors.red.shade200 : Colors.blue.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isDelete ? Colors.red : Colors.blue).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        value: _isDelete,
        onChanged: (v) {
          AppLogger.d(
            '[ProposeScreen] Toggle switched - isDelete: $_isDelete -> $v',
          );
          setState(() {
            _isDelete = v;
            // Reset selections khi đổi mode
            if (v) {
              _selectedStatus = null;
              _selectedEventType = null;
              AppLogger.d(
                '[ProposeScreen] Delete mode enabled - cleared status/type selections',
              );
            }
          });
        },
        title: Row(
          children: [
            Icon(
              _isDelete ? Icons.delete_outline : Icons.edit_outlined,
              color: _isDelete ? Colors.red.shade700 : Colors.blue.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isDelete ? 'Đề xuất xóa sự kiện' : 'Đề xuất cập nhật',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _isDelete
                      ? Colors.red.shade700
                      : const Color(0xFF1E293B),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _isDelete
                ? 'Yêu cầu xóa hoàn toàn sự kiện này khỏi hệ thống'
                : 'Đề xuất thay đổi trạng thái hoặc loại sự kiện',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        activeColor: Colors.red.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          _isDelete ? 'Đề xuất xóa sự kiện' : 'Đề xuất thay đổi',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thông tin hiện tại (chung cho cả 2 mode)
            _buildCurrentInfoCard(),

            const SizedBox(height: 16),

            // Toggle giữa xóa và cập nhật
            _buildActionToggle(),

            const SizedBox(height: 16),

            // Phần chọn trạng thái (chỉ hiện khi không xóa)
            _buildStatusSelectionCard(),
            if (!_isDelete) const SizedBox(height: 16),

            // Phần chọn loại sự kiện (chỉ hiện khi không xóa)
            _buildEventTypeSelectionCard(),
            if (!_isDelete) const SizedBox(height: 16),

            // Lý do đề xuất (chung cho cả 2 mode)
            _buildReasonCard(),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDelete
                      ? Colors.red.shade600
                      : const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Đang gửi...',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isDelete
                                ? Icons.delete_forever
                                : Icons.send_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isDelete
                                ? 'Gửi đề xuất xóa'
                                : 'Gửi đề xuất cập nhật',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
