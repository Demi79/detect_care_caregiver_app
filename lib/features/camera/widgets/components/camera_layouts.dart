import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/camera_card.dart';

class CameraList extends StatelessWidget {
  final List<CameraEntry> cameras;
  final Function(CameraEntry) onPlay;
  final Function(CameraEntry) onDelete;
  final Function(CameraEntry)? onEdit;
  final Function(CameraEntry)? onRefreshRequested;
  final Function(CameraEntry)? onShowTimeline;
  final String? searchQuery;
  final String? statusNote;

  const CameraList({
    super.key,
    required this.cameras,
    required this.onPlay,
    required this.onDelete,
    this.onEdit,
    this.onRefreshRequested,
    this.onShowTimeline,
    this.searchQuery,
    this.statusNote,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, i) {
        final camera = cameras[i];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            shadowColor: Colors.black12,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onPlay(camera),
              splashColor: Colors.blueAccent.withValues(alpha: 0.1 * 255),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 16.0,
                ),
                child: CameraCard(
                  key: ValueKey(camera.url),
                  camera: camera,
                  onPlay: onPlay,
                  onDelete: onDelete,
                  onEdit: onEdit,
                  onShowTimeline: onShowTimeline,
                  headerLabel: null,
                  isGrid2: false,
                  searchQuery: searchQuery,
                  statusNote: statusNote,
                ),
              ),
            ),
          ),
        );
      }, childCount: cameras.length),
    );
  }
}

class CameraGrid extends StatelessWidget {
  final List<CameraEntry> cameras;
  final Function(CameraEntry) onPlay;
  final Function(CameraEntry) onDelete;
  final Function(CameraEntry)? onEdit;
  final Function(CameraEntry)? onRefreshRequested;
  final Function(CameraEntry)? onShowTimeline;
  final String? searchQuery;
  final String? statusNote;

  const CameraGrid({
    super.key,
    required this.cameras,
    required this.onPlay,
    required this.onDelete,
    this.onEdit,
    this.onRefreshRequested,
    this.onShowTimeline,
    this.searchQuery,
    this.statusNote,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.of(context).size.width < 600 ? 2 : 3;
    final aspectRatio = MediaQuery.of(context).size.width < 600 ? 1.0 : 1.2;

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final camera = cameras[i];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onPlay(camera),
              splashColor: Colors.blueAccent.withValues(alpha: 0.1 * 255),
              child: CameraCard(
                key: ValueKey(camera.url),
                camera: camera,
                onPlay: onPlay,
                onDelete: onDelete,
                onEdit: onEdit,
                onRefreshRequested: onRefreshRequested != null
                    ? () => onRefreshRequested!(camera)
                    : null,
                onShowTimeline: onShowTimeline,
                headerLabel: null,
                isGrid2: true,
                height: 250,
                searchQuery: searchQuery,
                statusNote: statusNote,
              ),
            ),
          ),
        );
      }, childCount: cameras.length),
    );
  }
}
