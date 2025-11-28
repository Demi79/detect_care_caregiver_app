import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/action_button.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/camera_card_theme.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/crosshair_painter.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/grid_more_button.dart';
import 'package:detect_care_caregiver_app/features/camera/widgets/components/thumb_view.dart';
import 'package:flutter/material.dart';

class CameraCard extends StatelessWidget {
  final CameraEntry camera;
  final void Function(CameraEntry) onPlay;
  final void Function(CameraEntry) onDelete;
  final void Function(CameraEntry)? onEdit;
  final VoidCallback? onRefreshRequested;
  final void Function(CameraEntry)? onShowTimeline;
  final String? headerLabel;
  final bool isGrid2;
  final double? height;
  final double? width;
  final String? searchQuery;
  const CameraCard({
    super.key,
    required this.camera,
    required this.onPlay,
    required this.onDelete,
    this.onEdit,
    this.onRefreshRequested,
    this.onShowTimeline,
    this.headerLabel,
    this.isGrid2 = false,
    this.height,
    this.width,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CameraCardTheme(isGrid2);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: height ?? theme.maxHeight,
        minHeight: 160,
        minWidth: 120,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(theme.borderRadius),
          border: Border.all(
            color: camera.isOnline
                ? Colors.green.shade200
                : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: camera.isOnline
                  ? Colors.green.shade100.withValues(alpha: 0.3)
                  : Colors.black12,
              blurRadius: theme.boxShadowBlur,
              offset: const Offset(0, 4),
            ),
          ],
          gradient: camera.isOnline
              ? LinearGradient(
                  colors: [
                    Colors.white,
                    Colors.green.shade50.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          elevation: camera.isOnline ? theme.elevation + 2 : theme.elevation,
          borderRadius: BorderRadius.circular(theme.borderRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(theme.borderRadius),
            splashColor: camera.isOnline
                ? Colors.green.withValues(alpha: 0.1 * 255)
                : Colors.orange.withValues(alpha: 0.1 * 255),
            onTap: () => onPlay(camera),
            child: SizedBox(
              height: double.infinity,
              child: _buildCardContent(theme, context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String text,
    String? query,
    CameraCardTheme theme,
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (query == null || query.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: theme.nameFontSize,
          color: colorScheme.onSurface,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: theme.nameFontSize,
          color: colorScheme.onSurface,
        ),
      );
    }

    final endIndex = startIndex + query.length;
    final beforeText = text.substring(0, startIndex);
    final matchText = text.substring(startIndex, endIndex);
    final afterText = text.substring(endIndex);

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: beforeText,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: theme.nameFontSize,
              color: colorScheme.onSurface,
            ),
          ),
          TextSpan(
            text: matchText,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: theme.nameFontSize,
              color: Colors.orange,
              backgroundColor: Colors.orange.withValues(alpha: 0.2),
            ),
          ),
          TextSpan(
            text: afterText,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: theme.nameFontSize,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(CameraCardTheme theme, BuildContext context) {
    debugPrint(
      '[CameraCard] name: ${camera.name}, thumb: ${camera.thumb}, url: ${camera.url}',
    );
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PREVIEW
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(theme.borderRadius),
                ),
                child: (camera.thumb != null && camera.thumb!.isNotEmpty)
                    ? SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: ThumbView(
                          src: camera.thumb ?? '',
                          borderRadius:
                              0, // Remove border radius to avoid conflict with parent ClipRRect
                          isOnline: camera.isOnline,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(theme.borderRadius),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.camera_alt_outlined,
                            size: theme.thumbIconSize,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
              ),
              // crosshair mờ - chỉ hiển thị khi có thumbnail
              if (camera.thumb != null && camera.thumb!.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: CrosshairPainter()),
                  ),
                ),
              // If there's no thumbnail, draw the camera placeholder icon centered on top
              if (camera.thumb == null || camera.thumb!.isEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          size: theme.thumbIconSize * 0.8,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // BODY — make the body slightly different (soft gray) to separate from the preview
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade50,
                camera.isOnline
                    ? Colors.green.shade50.withValues(alpha: 0.3)
                    : Colors.grey.shade100,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(theme.borderRadius),
            ),
            border: Border(
              top: BorderSide(
                color: camera.isOnline
                    ? Colors.green.shade200
                    : Colors.grey.shade300,
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: theme.paddingH,
            vertical: isGrid2 ? 8 : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HÀNG 1: Tên (trái) + Action/More (phải)
              Row(
                children: [
                  Expanded(
                    child: _buildHighlightedText(
                      camera.name,
                      searchQuery,
                      theme,
                      context,
                    ),
                  ),
                  if (isGrid2)
                    Grid2MoreButton(
                      onPlay: () => onPlay(camera),
                      onEdit: onEdit != null ? () => onEdit!(camera) : null,
                      onDelete: () => onDelete(camera),
                      onRefresh: onRefreshRequested,
                      onTimeline: onShowTimeline != null
                          ? () => onShowTimeline!(camera)
                          : null,
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ActionButton(
                          icon: Icons.play_arrow,
                          color: camera.isOnline ? Colors.green : Colors.orange,
                          tooltip: 'Phát',
                          onPressed: () => onPlay(camera),
                          iconSize: theme.actionIconSize,
                          splashRadius: theme.actionSplash,
                        ),
                        if (onShowTimeline != null) ...[
                          const SizedBox(width: 8),
                          ActionButton(
                            icon: Icons.view_timeline_outlined,
                            color: Colors.deepOrange,
                            tooltip: 'Bản ghi',
                            onPressed: () => onShowTimeline!(camera),
                            iconSize: theme.actionIconSize,
                            splashRadius: theme.actionSplash,
                          ),
                        ],
                        const SizedBox(width: 8),
                        ActionButton(
                          icon: Icons.edit,
                          color: Colors.blue,
                          tooltip: 'Sửa',
                          onPressed: onEdit != null
                              ? () => onEdit!(camera)
                              : null,
                          iconSize: theme.actionIconSize,
                          splashRadius: theme.actionSplash,
                        ),
                        const SizedBox(width: 8),
                        ActionButton(
                          icon: Icons.delete,
                          color: Colors.red,
                          tooltip: 'Xóa',
                          onPressed: () => onDelete(camera),
                          iconSize: theme.actionIconSize,
                          splashRadius: theme.actionSplash,
                        ),
                        if (onRefreshRequested != null) ...[
                          const SizedBox(width: 8),
                          ActionButton(
                            icon: Icons.refresh,
                            color: Colors.green,
                            tooltip: 'Làm mới',
                            onPressed: onRefreshRequested,
                            iconSize: theme.actionIconSize,
                            splashRadius: theme.actionSplash,
                          ),
                        ],
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 6),
              // HÀNG 2: Nhãn "Camera" với cải thiện
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.labelPaddingH,
                  vertical: theme.labelPaddingV,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: camera.isOnline
                        ? [Colors.green.shade100, Colors.green.shade50]
                        : [Colors.orange[100]!, Colors.orange[50]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(theme.labelRadius),
                  border: Border.all(
                    color: camera.isOnline
                        ? Colors.green.shade300
                        : Colors.orange[200]!,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (camera.isOnline ? Colors.green : Colors.orange)
                          .shade200
                          .withValues(alpha: 0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      camera.isOnline ? Icons.videocam : Icons.videocam_off,
                      size: 12,
                      color: camera.isOnline
                          ? Colors.green.shade700
                          : Colors.orange[800],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      headerLabel ?? 'Camera',
                      style: TextStyle(
                        color: camera.isOnline
                            ? Colors.green.shade800
                            : Colors.orange[800],
                        fontSize: theme.labelFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
