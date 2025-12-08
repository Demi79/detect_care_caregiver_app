part of 'action_log_card.dart';

class _EventUpdateDraft {
  final String? status;
  final String? eventType;
  final String note;

  const _EventUpdateDraft({this.status, this.eventType, this.note = ''});
}

final Map<String, _EventUpdateDraft> _eventUpdateDraftCache = {};

_EventUpdateDraft? _getEventUpdateDraft(String eventId) =>
    _eventUpdateDraftCache[eventId];

void _persistEventUpdateDraft(
  String eventId, {
  String? status,
  String? eventType,
  required String note,
}) {
  final trimmedNote = note.trim();
  if (status == null && eventType == null && trimmedNote.isEmpty) {
    _eventUpdateDraftCache.remove(eventId);
    return;
  }
  _eventUpdateDraftCache[eventId] = _EventUpdateDraft(
    status: status,
    eventType: eventType,
    note: trimmedNote,
  );
}

void _clearEventUpdateDraft(String eventId) =>
    _eventUpdateDraftCache.remove(eventId);

extension _ActionLogCardUpdateModal on ActionLogCard {
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _detailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _kvRow(String key, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _jsonPreview(Map<String, dynamic> json) {
    final jsonString = const convert.JsonEncoder.withIndent('  ').convert(json);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        jsonString,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.white,
          height: 1.5,
        ),
      ),
    );
  }

  void _showUpdateModal(BuildContext pageContext) {
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

    final statusIcons = {
      'danger': Icons.dangerous_rounded,
      'warning': Icons.warning_rounded,
      'normal': Icons.check_circle_rounded,
      'unknown': Icons.help_rounded,
      'suspect': Icons.visibility_rounded,
      'abnormal': Icons.error_outline_rounded,
    };

    final eventId = data.eventId;
    final draft = _getEventUpdateDraft(eventId);
    final bool canEditEvent = _canEditEvent;
    final currentLower = data.status.toLowerCase();
    final statusOptions = allStatusOptions
        .where((s) => s != currentLower)
        .toList();

    final allEventTypes = [
      'fall',
      'abnormal_behavior',
      'emergency',
      'normal_activity',
      'sleep',
    ];

    final eventTypeIcons = {
      'fall': Icons.person_off_rounded,
      'abnormal_behavior': Icons.psychology_alt_rounded,
      'emergency': Icons.emergency_rounded,
      'normal_activity': Icons.directions_walk_rounded,
      'sleep': Icons.bedtime_rounded,
    };

    final availableEventTypes = allEventTypes
        .where((t) => t != data.eventType)
        .toList();

    final eventForImages = _buildEventLogForImages();
    final imagesFuture = loadEventImageUrls(eventForImages);
    final noteController = TextEditingController(text: draft?.note ?? '');

    String? selectedStatus = draft?.status;
    String? selectedEventType = draft?.eventType;
    String note = draft?.note ?? '';
    int highlightedImageIndex = 0;

    showDialog(
      context: pageContext,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setState) {
          bool hasChanges() =>
              selectedStatus != null ||
              selectedEventType != null ||
              note.trim().isNotEmpty;

          Future<bool> confirmDiscardChanges() async {
            if (!hasChanges()) return true;
            final result =
                await showDialog<bool>(
                  context: innerCtx,
                  builder: (confirmCtx) => AlertDialog(
                    title: const Text('Huỷ thay đổi?'),
                    content: const Text(
                      'Bạn có chắc muốn bỏ các thay đổi đang chỉnh sửa?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(confirmCtx).pop(false),
                        child: const Text('Tiếp tục chỉnh'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(confirmCtx).pop(true),
                        child: const Text('Huỷ thay đổi'),
                      ),
                    ],
                  ),
                ) ??
                false;
            return result;
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(innerCtx).unfocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // =================== HEADER ===================
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade500,
                                  Colors.blue.shade700,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.pending_actions_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cập nhật sự kiện',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Thay đổi trạng thái hoặc loại sự kiện',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final canClose = await confirmDiscardChanges();
                              if (canClose) {
                                Navigator.of(dialogCtx).pop();
                              }
                            },
                            icon: const Icon(Icons.close),
                            tooltip: 'Đóng',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!canEditEvent)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_clock,
                                color: Colors.orange.shade600,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cập nhật chỉ khả dụng trong vòng ${_kEventUpdateWindow.inDays} ngày kể từ khi sự kiện được ghi nhận.',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      FutureBuilder<List<String>>(
                        future: imagesFuture,
                        builder: (context, snapshot) {
                          Widget preview;
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            preview = Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          } else if (snapshot.hasError) {
                            preview = Container(
                              height: 120,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
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
                                      onTap: () => setState(() {
                                        highlightedImageIndex = index;
                                      }),
                                      child: Container(
                                        width: 120,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.blue.shade600
                                                : Colors.grey.shade200,
                                            width: isSelected ? 3 : 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.04,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stack,
                                                      ) => Container(
                                                        color: Colors
                                                            .grey
                                                            .shade100,
                                                        child: Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          color: Colors
                                                              .grey
                                                              .shade400,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Material(
                                                  color: Colors.white
                                                      .withOpacity(0.7),
                                                  shape: const CircleBorder(),
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    onTap: () =>
                                                        showActionLogCardImageViewer(
                                                          context,
                                                          urls,
                                                          index,
                                                        ),
                                                    child: const Padding(
                                                      padding: EdgeInsets.all(
                                                        6,
                                                      ),
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
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
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
                                  onPressed: () => _showImagesModal(
                                    pageContext,
                                    eventForImages,
                                  ),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text('Xem ảnh chi tiết'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 24),

                      // =================== TRẠNG THÁI HIỆN TẠI ===================
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.getStatusColor(
                            data.status,
                          ).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.getStatusColor(
                              data.status,
                            ).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              statusIcons[currentLower] ?? Icons.info_rounded,
                              color: AppTheme.getStatusColor(data.status),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 2,
                                children: [
                                  Text(
                                    'Trạng thái hiện tại:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    _translateStatusLocal(
                                      data.status,
                                    ).toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: AppTheme.getStatusColor(
                                        data.status,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =================== CHỌN TRẠNG THÁI MỚI ===================
                      _ElevatedCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Chọn trạng thái mới',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: statusOptions.map((status) {
                                final isSelected = selectedStatus == status;
                                final statusColor = AppTheme.getStatusColor(
                                  status,
                                );
                                final label = statusLabels[status]!;
                                final icon = statusIcons[status]!;

                                return GestureDetector(
                                  onTap: canEditEvent
                                      ? () => setState(() {
                                          selectedStatus = status;
                                          _persistEventUpdateDraft(
                                            eventId,
                                            status: selectedStatus,
                                            eventType: selectedEventType,
                                            note: note,
                                          );
                                        })
                                      : null,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? statusColor
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isSelected
                                            ? statusColor
                                            : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: statusColor.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          icon,
                                          size: 18,
                                          color: isSelected
                                              ? Colors.white
                                              : statusColor,
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          label.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (statusOptions.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Không có trạng thái khác để cập nhật.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =================== LOẠI SỰ KIỆN HIỆN TẠI ===================
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              eventTypeIcons[data.eventType] ??
                                  Icons.event_rounded,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Loại hiện tại: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              be.BackendEnums.eventTypeToVietnamese(
                                data.eventType,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =================== CHỌN LOẠI SỰ KIỆN MỚI ===================
                      _ElevatedCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.category_rounded,
                                  size: 18,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Chọn loại sự kiện mới',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: availableEventTypes.map((type) {
                                final label =
                                    be.BackendEnums.eventTypeToVietnamese(type);
                                final icon = eventTypeIcons[type]!;
                                final isSelected = selectedEventType == type;

                                return GestureDetector(
                                  onTap: canEditEvent
                                      ? () => setState(() {
                                          selectedEventType = type;
                                          _persistEventUpdateDraft(
                                            eventId,
                                            status: selectedStatus,
                                            eventType: selectedEventType,
                                            note: note,
                                          );
                                        })
                                      : null,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: isSelected
                                          ? LinearGradient(
                                              colors: [
                                                Colors.blue.shade500,
                                                Colors.blue.shade700,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: isSelected
                                          ? null
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue.shade700
                                            : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: Colors.blue.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          icon,
                                          size: 18,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =================== GHI CHÚ ===================
                      _ElevatedCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.notes_rounded,
                                  size: 18,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ghi chú (Tùy chọn)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: noteController,
                              enabled: canEditEvent,
                              readOnly: !canEditEvent,
                              onChanged: canEditEvent
                                  ? (v) => setState(() {
                                      note = v;
                                      _persistEventUpdateDraft(
                                        eventId,
                                        status: selectedStatus,
                                        eventType: selectedEventType,
                                        note: note,
                                      );
                                    })
                                  : null,
                              maxLines: 4,
                              maxLength: 240,
                              decoration: InputDecoration(
                                hintText: 'Nhập lý do cập nhật...',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.blue.shade600,
                                    width: 2,
                                  ),
                                ),
                                counterStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // =================== ACTION BUTTONS ===================
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final canClose = await confirmDiscardChanges();
                                if (canClose) {
                                  Navigator.of(dialogCtx).pop();
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                foregroundColor: Colors.grey.shade700,
                              ),
                              child: Text(
                                hasChanges() ? 'Huỷ thay đổi' : 'Đóng',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: canEditEvent
                                  ? () {
                                      if (selectedStatus == null &&
                                          selectedEventType == null) {
                                        ScaffoldMessenger.of(
                                          dialogCtx,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline_rounded,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Vui lòng chọn trạng thái hoặc loại sự kiện mới',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor:
                                                Colors.orange.shade600,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      _confirmUpdate(
                                        pageContext,
                                        selectedStatus ?? data.status,
                                        note,
                                        eventType: selectedEventType,
                                      );
                                    }
                                  : null,
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                'Lưu thay đổi',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                                shadowColor: Colors.blue.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => noteController.dispose());
  }

  Future<void> _confirmUpdate(
    BuildContext pageContext,
    String newStatus,
    String note, {
    String? eventType,
  }) async {
    const Map<String, int> statusRank = {
      'unknown': 0,
      'normal': 1,
      'suspect': 2,
      'abnormal': 3,
      'warning': 4,
      'danger': 5,
    };

    final currentLower = data.status.toLowerCase();
    final int currentRank = statusRank[currentLower] ?? 0;
    final int newRank = statusRank[newStatus.toLowerCase()] ?? 0;

    if (newRank > currentRank) {
      final proceedToImages =
          await showDialog<bool>(
            context: pageContext,
            builder: (ctx) => AlertDialog(
              title: const Text('Yêu cầu xem ảnh'),
              content: const Text(
                'Khi nâng trạng thái lên mức cao hơn, bạn phải xem ảnh liên quan trước khi tiếp tục. Mở xem ảnh bây giờ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Xem ảnh'),
                ),
              ],
            ),
          ) ??
          false;

      if (!proceedToImages) {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(
            content: const Text('Yêu cầu xem ảnh bị hủy'),
            backgroundColor: Colors.grey.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final eventForImages = EventLog(
        eventId: data.eventId,
        eventType: data.eventType,
        detectedAt: data.detectedAt,
        eventDescription: data.eventDescription,
        confidenceScore: data.confidenceScore,
        status: data.status,
        detectionData: data.detectionData,
        aiAnalysisResult: data.aiAnalysisResult,
        contextData: data.contextData,
        boundingBoxes: data.boundingBoxes,
        confirmStatus: data.confirmStatus,
        createdAt: data.createdAt,
        cameraId: data.cameraId,
      );

      try {
        await _showImagesModal(pageContext, eventForImages);
      } catch (_) {}
    }

    showDialog(
      context: pageContext,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.warning_outlined,
                color: Colors.orange.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Xác nhận',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Hành động này sẽ sửa đổi kết quả ghi nhận từ AI. Tiếp tục?',
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmCtx).pop(),
            child: Text('Hủy', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(confirmCtx).pop();
              final success = await _performUpdate(
                pageContext,
                newStatus,
                note,
                eventType: eventType,
              );
              if (success) {
                try {
                  Navigator.of(pageContext).pop(true);
                } catch (_) {}
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<bool> _performUpdate(
    BuildContext pageContext,
    String newStatus,
    String note, {
    String? eventType,
  }) async {
    final messenger = ScaffoldMessenger.of(pageContext);
    try {
      final ds = EventsRemoteDataSource();
      await ds.updateEvent(
        eventId: data.eventId,
        status: newStatus,
        notes: note.trim().isEmpty ? '-' : note.trim(),
        eventType: eventType ?? data.eventType,
      );

      try {
        final currentNorm = _normalizeLifecycle(
          data.lifecycleState,
        ).toUpperCase();
        if (currentNorm == 'NOTIFIED' || currentNorm == '') {
          try {
            await ds.updateEventLifecycle(
              eventId: data.eventId,
              lifecycleState: 'ACKNOWLEDGED',
            );
          } catch (e) {
            try {
              print(
                '[ActionLogCard] Failed to update lifecycle to ACKNOWLEDGED: $e',
              );
            } catch (_) {}
          }
        }
      } catch (_) {}

      messenger.showSnackBar(
        SnackBar(
          content: const Text('Cập nhật sự kiện thành công'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      try {
        Navigator.of(pageContext, rootNavigator: true).maybePop();
      } catch (_) {}
      try {
        AppEvents.instance.notifyEventsChanged();
      } catch (_) {}
      if (onUpdated != null) onUpdated!(newStatus);
      _clearEventUpdateDraft(data.eventId);
      return true;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Cập nhật sự kiện thất bại: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }
}
