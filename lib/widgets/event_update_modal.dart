import 'dart:io';

import 'package:detect_care_caregiver_app/core/events/app_events.dart';
import 'package:detect_care_caregiver_app/core/theme/app_theme.dart';
import 'package:detect_care_caregiver_app/core/utils/backend_enums.dart' as be;
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/widgets/action_log_card.dart';
import 'package:detect_care_caregiver_app/features/home/service/event_images_loader.dart';
import 'package:flutter/material.dart';

typedef LoadImagesFn = Future<List<dynamic>> Function(dynamic eventForImages);
typedef DraftGetterFn = dynamic Function(String eventId);
typedef PersistDraftFn =
    void Function(
      String eventId, {
      String? status,
      String? eventType,
      String? note,
    });
typedef ConfirmUpdateFn =
    void Function(
      BuildContext pageContext,
      String status,
      String note, {
      String? eventType,
    });
typedef BuildImageWidgetFn = Widget Function(dynamic imageSource);
typedef ShowImagesModalFn =
    void Function(BuildContext ctx, dynamic eventForImages);

showEventUpdateModal({
  required BuildContext pageContext,
  required dynamic data,
  required bool canEditEvent,
  required DraftGetterFn getEventUpdateDraft,
  required PersistDraftFn persistEventUpdateDraft,
  required ConfirmUpdateFn confirmUpdate,
  required LoadImagesFn loadEventImageUrls,
  required dynamic Function() buildEventLogForImages,
  required ShowImagesModalFn showImagesModal,
  required BuildImageWidgetFn buildImageWidget,
  required String Function(String) translateStatusLocal,
  required Color Function(String) getStatusColor,
  required int eventUpdateWindowDays,
  List<String>? allStatusOptions,
  Map<String, String>? statusLabels,
  Map<String, IconData>? statusIcons,
  List<String>? allEventTypes,
  Map<String, IconData>? eventTypeIcons,
}) {
  final allStatusOptions0 =
      allStatusOptions ??
      ['danger', 'warning', 'normal', 'unknown', 'suspect', 'abnormal'];

  final statusLabels0 =
      statusLabels ??
      {
        'danger': 'Nguy hiểm',
        'warning': 'Cảnh báo',
        'normal': 'Bình thường',
        'unknown': 'Không xác định',
        'suspect': 'Đáng ngờ',
        'abnormal': 'Bất thường',
      };

  final statusIcons0 =
      statusIcons ??
      {
        'danger': Icons.dangerous_rounded,
        'warning': Icons.warning_rounded,
        'normal': Icons.check_circle_rounded,
        'unknown': Icons.help_rounded,
        'suspect': Icons.visibility_rounded,
        'abnormal': Icons.error_outline_rounded,
      };

  final allEventTypes0 =
      allEventTypes ??
      ['fall', 'abnormal_behavior', 'emergency', 'normal_activity', 'sleep'];

  final eventTypeIcons0 =
      eventTypeIcons ??
      {
        'fall': Icons.person_off_rounded,
        'abnormal_behavior': Icons.psychology_alt_rounded,
        'emergency': Icons.emergency_rounded,
        'normal_activity': Icons.directions_walk_rounded,
        'sleep': Icons.bedtime_rounded,
      };

  final eventId = data.eventId as String;
  final draft = getEventUpdateDraft(eventId);
  final currentLower = (data.status as String).toLowerCase();
  final statusOptions = allStatusOptions0
      .where((s) => s != currentLower)
      .toList();

  final availableEventTypes = allEventTypes0
      .where((t) => t != data.eventType)
      .toList();

  final eventForImages = buildEventLogForImages();
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

        final rawStatus = (data.status ?? '')?.toString() ?? '';
        final rawLifecycle = (data.lifecycleState ?? '')?.toString() ?? '';
        final rawPrevious = (data.previousStatus ?? '')?.toString() ?? '';

        String displayStatusLabel0() {
          if (rawStatus.trim().isNotEmpty &&
              rawStatus.trim().toLowerCase() != 'unknown') {
            return translateStatusLocal(rawStatus);
          }
          if (rawLifecycle.trim().isNotEmpty) {
            return be.BackendEnums.lifecycleStateToVietnamese(rawLifecycle);
          }
          if (rawPrevious.trim().isNotEmpty) {
            return translateStatusLocal(rawPrevious);
          }
          return translateStatusLocal(rawStatus);
        }

        final displayStatusLabel = displayStatusLabel0();

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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Đề xuất sự kiện',
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
                            if (canClose) Navigator.of(dialogCtx).pop();
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
                                'Đề xuất chỉ khả dụng trong vòng $eventUpdateWindowDays ngày kể từ khi sự kiện được ghi nhận.',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    FutureBuilder<List<dynamic>>(
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
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
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
                          final imageSources = snapshot.data ?? const [];
                          if (imageSources.isEmpty) {
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
                              imageSources.length - 1,
                            );
                            preview = SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemBuilder: (context, index) {
                                  final imageSource = imageSources[index];
                                  final isSelected = index == previewIndex;
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      highlightedImageIndex = index;
                                    }),
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
                                            color: Colors.black.withOpacity(
                                              0.04,
                                            ),
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
                                              child: buildImageWidget(
                                                imageSource,
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Material(
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
                                                shape: const CircleBorder(),
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  onTap: () => showImagesModal(
                                                    context,
                                                    eventForImages,
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
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemCount: imageSources.length,
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
                                onPressed: () => showImagesModal(
                                  pageContext,
                                  eventForImages,
                                ),
                                icon: const Icon(Icons.photo_library_outlined),
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

                    // Current status
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: getStatusColor(data.status).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: getStatusColor(data.status).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            statusIcons0[currentLower] ?? Icons.info_rounded,
                            color: getStatusColor(data.status),
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
                                  displayStatusLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: getStatusColor(data.status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Select new status
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
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
                                    fontSize: 12,
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
                                final statusColor = getStatusColor(status);
                                final label = statusLabels0[status]!;
                                final icon = statusIcons0[status]!;

                                return GestureDetector(
                                  onTap: canEditEvent
                                      ? () => setState(() {
                                          selectedStatus = status;
                                          persistEventUpdateDraft(
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
                                  'Không có trạng thái khác để đề xuất.',
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
                    ),

                    const SizedBox(height: 20),

                    // Current event type
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
                            eventTypeIcons0[data.eventType] ??
                                Icons.event_rounded,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 2,
                              children: [
                                Text(
                                  'Loại hiện tại:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  translateStatusLocal(data.eventType),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Choose new event type
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
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
                                final label = translateStatusLocal(type);
                                final icon = eventTypeIcons0[type]!;
                                final isSelected = selectedEventType == type;

                                return GestureDetector(
                                  onTap: canEditEvent
                                      ? () => setState(() {
                                          selectedEventType = type;
                                          persistEventUpdateDraft(
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
                    ),

                    const SizedBox(height: 20),

                    // Notes
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
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
                                      persistEventUpdateDraft(
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
                                hintText: 'Nhập lý do đề xuất...',
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
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final canClose = await confirmDiscardChanges();
                              if (canClose) Navigator.of(dialogCtx).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                              style: TextStyle(
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
                                    // Ensure there is at least one change (status/eventType/note)
                                    if (selectedStatus == null &&
                                        selectedEventType == null &&
                                        note.trim().isEmpty) {
                                      ScaffoldMessenger.of(
                                        dialogCtx,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: const [
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    // Disallow selecting the same status or event type as the original
                                    if (selectedStatus != null &&
                                        selectedStatus == data.status) {
                                      ScaffoldMessenger.of(
                                        dialogCtx,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Không thể đề xuất về trạng thái hiện tại',
                                          ),
                                          backgroundColor:
                                              Colors.orange.shade600,
                                        ),
                                      );
                                      return;
                                    }
                                    if (selectedEventType != null &&
                                        selectedEventType == data.eventType) {
                                      ScaffoldMessenger.of(
                                        dialogCtx,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Không thể đề xuất về loại sự kiện hiện tại',
                                          ),
                                          backgroundColor:
                                              Colors.orange.shade600,
                                        ),
                                      );
                                      return;
                                    }

                                    confirmUpdate(
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
                              'Đề xuất thay đổi',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
  ).whenComplete(() {
    Future.delayed(const Duration(milliseconds: 400), () {
      try {
        noteController.dispose();
      } catch (_) {}
    });
  });
}

// Minimal in-memory draft cache used by the shared modal wrapper.
class _SharedDraft {
  final String? status;
  final String? eventType;
  final String note;

  const _SharedDraft({this.status, this.eventType, this.note = ''});
}

final Map<String, _SharedDraft> _sharedDraftCache = {};

_SharedDraft? _getSharedDraft(String eventId) => _sharedDraftCache[eventId];

void _persistSharedDraft(
  String eventId, {
  String? status,
  String? eventType,
  required String note,
}) {
  final trimmedNote = note.trim();
  if (status == null && eventType == null && trimmedNote.isEmpty) {
    _sharedDraftCache.remove(eventId);
    return;
  }
  _sharedDraftCache[eventId] = _SharedDraft(
    status: status,
    eventType: eventType,
    note: trimmedNote,
  );
}

Future<void> showEventUpdateModalForEvent({
  required BuildContext context,
  required EventLog event,
  dynamic imageSourceEvent,
  required bool canEditEvent,
}) async {
  try {
    debugPrint('\n[EventUpdateModal] Opening modal for event ${event.eventId}');
    debugPrint(' - status: ${event.status}');
    debugPrint(' - eventType: ${event.eventType}');
    debugPrint(' - lifecycleState: ${event.lifecycleState}');
    debugPrint(' - previousStatus: ${event.previousStatus}');
    debugPrint(' - detectedAt: ${event.detectedAt}');
    debugPrint(' - createdAt: ${event.createdAt}');
  } catch (_) {}

  var resolvedEvent = event;
  try {
    final det = event.detectionData;
    String? snapshotId;
    try {
      final s1 = det['snapshot_id'] ?? det['snapshotId'];
      String? s2;
      final snapNode = det['snapshot'];
      if (snapNode is Map) {
        s2 = snapNode['snapshot_id'] ?? snapNode['id'];
      }
      snapshotId = (s1 ?? s2)?.toString();
    } catch (_) {
      snapshotId = null;
    }
    if (snapshotId != null && snapshotId.isNotEmpty) {
      try {
        final ds = EventsRemoteDataSource();
        final found = await ds.listEvents(
          limit: 1,
          extraQuery: {'snapshot_id': snapshotId},
        );
        if (found.isNotEmpty) {
          try {
            resolvedEvent = EventLog.fromJson(found.first);
            debugPrint(
              '[EventUpdateModal] Resolved event by snapshot $snapshotId -> ${resolvedEvent.eventId}',
            );
            // also update imageSourceEvent if it was the previous event
            if (imageSourceEvent == event) imageSourceEvent = resolvedEvent;
          } catch (_) {}
        }
      } catch (e) {
        debugPrint(
          '[EventUpdateModal] Failed to resolve event by snapshot: $e',
        );
      }
    }
    try {
      final det = event.detectionData;
      final ctx = event.contextData;
      final recordingId =
          (det['recording_id'] ??
                  det['recordingId'] ??
                  ctx['recording_id'] ??
                  ctx['recordingId'])
              ?.toString();
      if ((resolvedEvent.eventId.isEmpty ||
              resolvedEvent.status.toString().trim().toLowerCase() ==
                  'unknown') &&
          recordingId != null &&
          recordingId.isNotEmpty) {
        try {
          final ds = EventsRemoteDataSource();
          final found = await ds.listEvents(
            limit: 1,
            extraQuery: {'recording_id': recordingId},
          );
          if (found.isNotEmpty) {
            try {
              resolvedEvent = EventLog.fromJson(found.first);
              debugPrint(
                '[EventUpdateModal] Resolved event by recording $recordingId -> ${resolvedEvent.eventId}',
              );
              if (imageSourceEvent == event) imageSourceEvent = resolvedEvent;
            } catch (_) {}
          }
        } catch (e) {
          debugPrint(
            '[EventUpdateModal] Failed to resolve event by recording: $e',
          );
        }
      }
    } catch (_) {}
  } catch (_) {}

  showEventUpdateModal(
    pageContext: context,
    data: resolvedEvent,
    canEditEvent: canEditEvent,
    getEventUpdateDraft: (id) {
      final d = _getSharedDraft(id);
      return d == null
          ? null
          : {'status': d.status, 'eventType': d.eventType, 'note': d.note};
    },
    persistEventUpdateDraft: (id, {status, eventType, note}) =>
        _persistSharedDraft(
          id,
          status: status,
          eventType: eventType,
          note: note ?? '',
        ),
    confirmUpdate: (pageContext, newStatus, note, {eventType}) async {
      final confirmed =
          await showDialog<bool>(
            context: pageContext,
            builder: (confirmCtx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(confirmCtx).pop(false),
                  child: Text(
                    'Hủy',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(confirmCtx).pop(true),
                  child: const Text('Xác nhận'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed) return;

      final messenger = ScaffoldMessenger.of(pageContext);
      try {
        // await ds.updateEvent(
        //   eventId: resolvedEvent.eventId,
        //   status: newStatus,
        //   notes: note.trim().isEmpty ? '-' : note.trim(),
        //   eventType: eventType ?? resolvedEvent.eventType,
        // );
        final svc = EventService.withDefaultClient();
        await svc.proposeEventStatus(
          eventId: resolvedEvent.eventId,
          proposedStatus: newStatus,
          proposedEventType: eventType ?? resolvedEvent.eventType,
          reason: note.trim().isEmpty ? '-' : note.trim(),
        );

        messenger.showSnackBar(
          SnackBar(
            content: const Text('Đề xuất sự kiện thành công'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        try {
          AppEvents.instance.notifyTableChanged('event_detections');
        } catch (_) {}
        try {
          Navigator.of(pageContext).maybePop();
        } catch (_) {}
        _persistSharedDraft(
          resolvedEvent.eventId,
          status: null,
          eventType: null,
          note: '',
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Đề xuất sự kiện thất bại: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    },
    loadEventImageUrls: (evt) =>
        loadEventImageUrls(evt as EventLog, bypassCache: true).then((l) => l),
    buildEventLogForImages: () => imageSourceEvent ?? event,
    showImagesModal: (ctx, evt) =>
        showActionLogImagesModal(context: ctx, event: evt as EventLog),
    buildImageWidget: (imageSource) {
      final path = imageSource is ImageSource
          ? imageSource.path
          : (imageSource as String);
      final isLocal = imageSource is ImageSource
          ? imageSource.isLocal
          : !path.startsWith('http');
      if (isLocal) {
        return Image.file(File(path), fit: BoxFit.contain);
      }
      return Image.network(path, fit: BoxFit.contain);
    },

    translateStatusLocal: (s) {
      final low = s.toString().trim().toLowerCase();
      const eventTypes = [
        'fall',
        'abnormal_behavior',
        'emergency',
        'normal_activity',
        'sleep',
      ];
      if (eventTypes.contains(low)) {
        return be.BackendEnums.eventTypeToVietnamese(low);
      }
      return be.BackendEnums.statusToVietnamese(low);
    },
    getStatusColor: (s) => AppTheme.getStatusColor(s),
    eventUpdateWindowDays: 2,
  );
}
