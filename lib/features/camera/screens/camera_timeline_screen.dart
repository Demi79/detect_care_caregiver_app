import 'dart:async';

import 'package:detect_care_caregiver_app/features/camera/controllers/camera_timeline_controller.dart';
import 'package:detect_care_caregiver_app/features/camera/data/camera_timeline_api.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/camera_timeline_components.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/camera_timeline_date_selector.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/camera_timeline_empty_preview.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/camera_timeline_list.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/timeline/camera_timeline_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CameraTimelineScreen extends StatefulWidget {
  final CameraEntry camera;
  final DateTime? initialDay;
  final CameraTimelineApi? timelineApi;
  final bool loadFromApi;
  final bool embedded;

  const CameraTimelineScreen({
    super.key,
    required this.camera,
    this.initialDay,
    this.timelineApi,
    this.loadFromApi = true,
    this.embedded = false,
  });

  @override
  State<CameraTimelineScreen> createState() => _CameraTimelineScreenState();
}

class _CameraTimelineScreenState extends State<CameraTimelineScreen> {
  late final CameraTimelineController _controller;

  // Không cần hiển thị nhóm mode nữa — để trống list sẽ ẩn hoàn toàn phần selector.
  final _modeOptions = const <CameraTimelineModeOption>[];

  @override
  void initState() {
    super.initState();
    _controller = CameraTimelineController(
      api: widget.timelineApi ?? CameraTimelineApi(),
      cameraId: widget.camera.id,
      initialDay: widget.initialDay ?? DateTime.now(),
      loadFromApi: widget.loadFromApi,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDay(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<CameraTimelineController>(
        builder: (context, ctl, _) {
          final body = _buildTimelineBody(context, ctl);
          if (widget.embedded) return body;
          return Scaffold(
            backgroundColor: const Color(0xFFF6F6F6),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.black87,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.camera.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Camera ghi hình',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Colors.black87,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cài đặt đang được phát triển.'),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: body,
          );
        },
      ),
    );
  }

  Widget _buildTimelineBody(
    BuildContext context,
    CameraTimelineController ctl,
  ) {
    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF6F6F6),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: _buildEmbeddedTimeline(ctl),
      );
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final timelineHeight = (constraints.maxHeight * 0.45).clamp(
            260.0,
            480.0,
          );
          // Wrap the timeline body in a Stack so we can show a full-screen
          // semi-transparent loading overlay while the controller is loading.
          return RefreshIndicator(
            onRefresh: () async {
              if (widget.loadFromApi) {
                await ctl.loadTimeline();
              } else {
                ctl.loadDemo();
              }
            },
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CameraTimelineEmptyPreview(
                          clips: ctl.clips,
                          isLoading: ctl.isLoading,
                        ),
                        const SizedBox(height: 16),
                        if (_modeOptions.isNotEmpty) ...[
                          CameraTimelineModeSelector(
                            options: _modeOptions,
                            selectedIndex: ctl.selectedModeIndex,
                            onTap: (i) => ctl.changeMode(i),
                          ),
                          const SizedBox(height: 12),
                        ],
                        CameraTimelineDateSelector(
                          formattedDay: _formatDay(ctl.selectedDay),
                          onPrev: () => ctl.changeDay(-1),
                          onNext: () => ctl.changeDay(1),
                          onMenu: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Menu ngày đang phát triển.'),
                                ),
                              ),
                          compact: false,
                          showZoom: true,
                          zoomLevel: ctl.zoomLevel,
                          onAdjustZoom: (d) => ctl.adjustZoom(d),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          // increase timeline area more to give ample room for preview cards
                          // (responsive multiplier and higher clamps)
                          height: (timelineHeight * 1.35).clamp(380.0, 720.0),
                          child: CameraTimelineList(
                            entries: ctl.entries,
                            selectedClipId: ctl.selectedClipId,
                            isLoading: ctl.isLoading,
                            errorMessage: ctl.errorMessage,
                            compact: false,
                            zoomLevel: ctl.zoomLevel,
                            onAdjustZoom: (d) => ctl.adjustZoom(d),
                            onSelectClip: (id) => ctl.selectClip(id),
                            onRetry: () => unawaited(ctl.loadTimeline()),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Global overlay when loading
                if (ctl.isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.08),
                      child: const Center(
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmbeddedTimeline(CameraTimelineController ctl) {
    const timelineHeight = 380.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_modeOptions.isNotEmpty) ...[
          CameraTimelineModeSelector(
            options: _modeOptions,
            selectedIndex: ctl.selectedModeIndex,
            onTap: (i) => ctl.changeMode(i),
            compact: true,
          ),
          const SizedBox(height: 12),
        ],
        CameraTimelineDateSelector(
          formattedDay: _formatDay(ctl.selectedDay),
          onPrev: () => ctl.changeDay(-1),
          onNext: () => ctl.changeDay(1),
          onMenu: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Menu ngày đang phát triển.')),
          ),
          compact: true,
          showZoom: false,
          zoomLevel: ctl.zoomLevel,
          onAdjustZoom: (d) => ctl.adjustZoom(d),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: timelineHeight,
          child: CameraTimelineList(
            entries: ctl.entries,
            selectedClipId: ctl.selectedClipId,
            isLoading: ctl.isLoading,
            errorMessage: ctl.errorMessage,
            compact: true,
            zoomLevel: ctl.zoomLevel,
            onAdjustZoom: (d) => ctl.adjustZoom(d),
            onSelectClip: (id) => ctl.selectClip(id),
            onRetry: () => unawaited(ctl.loadTimeline()),
          ),
        ),
      ],
    );
  }
}
