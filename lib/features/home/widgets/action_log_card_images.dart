part of 'action_log_card.dart';

extension _ActionLogCardImages on ActionLogCard {
  Future<void> _showImagesModal(BuildContext pageContext, EventLog event) {
    AppLogger.d(
      '\n[ActionLogCard] Đang tải ảnh cho sự kiện ${event.eventId}...',
    );
    final future = loadEventImageUrls(event).then((urls) {
      AppLogger.d('[ActionLogCard] Tìm thấy ${urls.length} ảnh:');
      for (var url in urls) {
        AppLogger.d(' - $url');
      }
      return urls;
    });

    return showDialog(
      context: pageContext,
      builder: (dialogCtx) {
        int? selectedIndex;
        bool isAlarmWorking = false;

        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(pageContext).size.width * 0.9,
              height: MediaQuery.of(pageContext).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.blue.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Hình ảnh',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      // Camera button
                      IconButton(
                        onPressed: () {
                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                          Future.delayed(const Duration(milliseconds: 250), () {
                            _openCameraForEvent(pageContext, event);
                          });
                        },
                        icon: const Icon(Icons.videocam_outlined),
                        tooltip: 'Xem camera',
                      ),
                      // Edit button — disable if there's an active pending proposal
                      FutureBuilder<EventLog>(
                        future: EventRepository(
                          EventService.withDefaultClient(),
                        ).getEventDetails(data.eventId),
                        builder: (ctx, snap) {
                          bool enabled = _canEditEvent;
                          if (snap.connectionState == ConnectionState.done &&
                              !snap.hasError &&
                              snap.data != null) {
                            final current = snap.data!;
                            final hasPending =
                                current.proposedStatus != null &&
                                (current.pendingUntil != null &&
                                    current.pendingUntil!.isAfter(
                                      DateTime.now(),
                                    ));
                            if (hasPending) enabled = false;
                          }

                          return IconButton(
                            onPressed: enabled
                                ? () async {
                                    try {
                                      final current =
                                          snap.data ??
                                          await EventRepository(
                                            EventService.withDefaultClient(),
                                          ).getEventDetails(data.eventId);
                                      if (current.proposedStatus != null &&
                                          (current.pendingUntil != null &&
                                              current.pendingUntil!.isAfter(
                                                DateTime.now(),
                                              ))) {
                                        await showDialog<void>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Đã có đề xuất'),
                                            content: const Text(
                                              'Sự kiện đang có đề xuất chờ duyệt.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(),
                                                child: const Text('Đóng'),
                                              ),
                                            ],
                                          ),
                                        );
                                        return;
                                      }
                                    } catch (e) {
                                      print(
                                        '[ActionLogCard] pre-check getEventDetails failed: $e',
                                      );
                                    }

                                    try {
                                      Navigator.of(context).pop();
                                    } catch (_) {}
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProposeScreen(logEntry: data),
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Cập nhật sự kiện',
                          );
                        },
                      ),
                      // Close button
                      IconButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Main content
                  Expanded(
                    child: FutureBuilder<List<String>>(
                      future: future,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              'Lỗi tải ảnh: ${snap.error}',
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          );
                        }

                        final urls = snap.data ?? const [];
                        if (urls.isEmpty) {
                          return _emptyImages();
                        }

                        selectedIndex ??= 0;
                        final selectedUrl = urls[selectedIndex!];

                        return Column(
                          children: [
                            Expanded(
                              child: GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.3,
                                    ),
                                itemCount: urls.length,
                                itemBuilder: (context, index) {
                                  final url = urls[index];
                                  final isSelected = selectedIndex == index;
                                  return GestureDetector(
                                    onTap: () {
                                      if (!dialogCtx.mounted) return;
                                      setDialogState(
                                        () => selectedIndex = index,
                                      );
                                    },
                                    child: Material(
                                      clipBehavior: Clip.antiAlias,
                                      elevation: 4,
                                      shadowColor: Colors.black.withOpacity(
                                        0.12,
                                      ),
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: isSelected
                                              ? AppTheme.primaryBlue
                                              : Colors.grey.shade200,
                                          width: isSelected ? 3 : 1,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Image.network(
                                              url,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (c, w, progress) {
                                                return progress == null
                                                    ? w
                                                    : const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      );
                                              },
                                              errorBuilder: (c, err, st) =>
                                                  Container(
                                                    color: Colors.grey.shade100,
                                                    alignment: Alignment.center,
                                                    child: Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      size: 32,
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    Color.fromRGBO(
                                                      0,
                                                      0,
                                                      0,
                                                      0.7,
                                                    ),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                              child: Text(
                                                'Ảnh ${index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () {
                                                if (!dialogCtx.mounted) return;
                                                setDialogState(
                                                  () => selectedIndex = index,
                                                );
                                                showActionLogCardImageViewer(
                                                  dialogCtx,
                                                  urls,
                                                  index,
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color.fromRGBO(
                                                    255,
                                                    255,
                                                    255,
                                                    0.9,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.zoom_in,
                                                  size: 16,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Nút gọi khẩn cấp — Tự động ẩn nếu hết thời gian cho phép
                                  if (!_isUpdateWindowExpired)
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _initiateEmergencyCall(dialogCtx),
                                      icon: const Icon(Icons.call),
                                      label: const Text('Gọi khẩn cấp'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.grey.shade800,
                                        elevation: 0,
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyImages() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Không có ảnh',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chưa có ảnh được ghi lại cho sự kiện này.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmAlarmDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF8FAFC),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
