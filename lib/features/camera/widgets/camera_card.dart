import 'dart:convert';
import 'dart:io';

import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:flutter/material.dart';

class CameraCard extends StatelessWidget {
  final CameraEntry camera;
  final void Function(CameraEntry) onPlay;
  final void Function(CameraEntry) onDelete;
  final void Function(CameraEntry)? onEdit;
  final VoidCallback? onRefreshRequested;
  final String? headerLabel;
  final bool isGrid2;
  final double? height;
  final double? width;
  const CameraCard({
    super.key,
    required this.camera,
    required this.onPlay,
    required this.onDelete,
    this.onEdit,
    this.onRefreshRequested,
    this.headerLabel,
    this.isGrid2 = false,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final double borderRadius = isGrid2 ? 18 : 24;
    final double elevation = isGrid2 ? 4 : 8;
    final double boxShadowBlur = isGrid2 ? 7 : 12;
    final double thumbIconSize = isGrid2 ? 24 : 32;
    final double statusChipTop = isGrid2 ? 8 : 12;
    final double statusChipRight = isGrid2 ? 8 : 12;
    final double paddingH = isGrid2 ? 10 : 16;
    final double paddingV = isGrid2 ? 7 : 12;
    final double labelFontSize = isGrid2 ? 11 : 13;
    final double labelPaddingH = isGrid2 ? 7 : 10;
    final double labelPaddingV = isGrid2 ? 3 : 4;
    final double labelRadius = isGrid2 ? 6 : 8;
    final double nameFontSize = isGrid2 ? 16 : 22;
    final double actionIconSize = isGrid2 ? 13 : 16;
    final double actionSplash = isGrid2 ? 18 : 26;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: height ?? (isGrid2 ? 220 : double.infinity),
        minHeight: 160,
        minWidth: 120,
      ),
      child: Material(
        color: Colors.white,
        elevation: elevation,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: Colors.orange.withAlpha((0.12 * 255).round()),
          onTap: () => onPlay(camera),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: boxShadowBlur,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _buildCardContent(
              borderRadius,
              thumbIconSize,
              statusChipTop,
              statusChipRight,
              paddingH,
              paddingV,
              labelPaddingH,
              labelPaddingV,
              labelRadius,
              labelFontSize,
              actionIconSize,
              actionSplash,
              nameFontSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(
    double borderRadius,
    double thumbIconSize,
    double statusChipTop,
    double statusChipRight,
    double paddingH,
    double paddingV,
    double labelPaddingH,
    double labelPaddingV,
    double labelRadius,
    double labelFontSize,
    double actionIconSize,
    double actionSplash,
    double nameFontSize,
  ) {
    debugPrint(
      '[CameraCard] name: ${camera.name}, thumb: ${camera.thumb}, url: ${camera.url}',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PREVIEW
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(borderRadius),
              ),
              child: (camera.thumb != null && camera.thumb!.isNotEmpty)
                  ? AspectRatio(
                      aspectRatio: 5 / 4,
                      child: ThumbView(
                        src: camera.thumb ?? '',
                        borderRadius: 12,
                        isOnline: camera.isOnline,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : AspectRatio(
                      aspectRatio: 5 / 4,
                      child: Container(
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.camera_alt_outlined,
                          size: thumbIconSize,
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
            ),
            // crosshair mờ
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: CrosshairPainter()),
              ),
            ),
          ],
        ),

        // BODY
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: paddingH,
            vertical: isGrid2 ? 3 : 6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HÀNG 1: Tên (trái) + Action/More (phải)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      camera.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: nameFontSize,
                        color: const Color(0xFF2C3146),
                      ),
                    ),
                  ),
                  if (isGrid2)
                    _Grid2MoreButton(
                      onPlay: () => onPlay(camera),
                      onEdit: onEdit != null ? () => onEdit!(camera) : null,
                      onDelete: () => onDelete(camera),
                      onRefresh: onRefreshRequested,
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          icon: Icons.play_arrow,
                          color: Colors.orange,
                          tooltip: 'Phát',
                          onPressed: () => onPlay(camera),
                          iconSize: actionIconSize,
                          splashRadius: actionSplash,
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.edit,
                          color: Colors.blue,
                          tooltip: 'Sửa',
                          onPressed: onEdit != null
                              ? () => onEdit!(camera)
                              : null,
                          iconSize: actionIconSize,
                          splashRadius: actionSplash,
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.delete,
                          color: Colors.red,
                          tooltip: 'Xóa',
                          onPressed: () => onDelete(camera),
                          iconSize: actionIconSize,
                          splashRadius: actionSplash,
                        ),
                        if (onRefreshRequested != null) ...[
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.refresh,
                            color: Colors.green,
                            tooltip: 'Làm mới',
                            onPressed: onRefreshRequested,
                            iconSize: actionIconSize,
                            splashRadius: actionSplash,
                          ),
                        ],
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 6),

              // HÀNG 2: Nhãn "Camera"
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: labelPaddingH,
                  vertical: labelPaddingV,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(labelRadius),
                ),
                child: Text(
                  headerLabel ?? 'Camera',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Vẽ crosshair mờ ở giữa card
class CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withAlpha((0.08 * 255).round())
      ..strokeWidth = 1.2;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.22, paint);
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      paint,
    );
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;
  final double splashRadius;
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onPressed,
    this.iconSize = 16,
    this.splashRadius = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        icon: Icon(icon, color: color, size: iconSize),
        tooltip: tooltip,
        onPressed: onPressed,
        splashRadius: splashRadius,
      ),
    );
  }
}

class ThumbView extends StatelessWidget {
  final String src;
  final double borderRadius;
  final bool isOnline;
  final double? width;
  final double? height;
  const ThumbView({
    super.key,
    required this.src,
    this.borderRadius = 12,
    this.isOnline = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.camera_alt_outlined, color: Colors.grey[300]),
    );
    Widget statusDot = Positioned(
      top: 8,
      right: 8,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: isOnline ? Colors.green : Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
    try {
      if (src.startsWith('http')) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.network(
                src,
                fit: BoxFit.cover,
                width: width,
                height: height,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
            statusDot,
          ],
        );
      }
      if (src.startsWith('data:image')) {
        final comma = src.indexOf(',');
        final b64 = comma >= 0 ? src.substring(comma + 1) : src;
        final bytes = base64Decode(b64);
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                width: width,
                height: height,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
            statusDot,
          ],
        );
      }
      // Assume file path
      String path = src;
      final q = path.indexOf('?');
      final hash = path.indexOf('#');
      final cut = [q, hash].where((i) => i >= 0).fold<int>(-1, (a, b) {
        if (a < 0) return b;
        if (b < 0) return a;
        return a < b ? a : b;
      });
      if (cut >= 0) path = path.substring(0, cut);
      final file = path.startsWith('file:')
          ? File(Uri.parse(path).toFilePath())
          : File(path);
      return FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !(snapshot.data ?? false)) {
            return fallback;
          }
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  width: width,
                  height: height,
                  errorBuilder: (_, __, ___) => fallback,
                ),
              ),
              statusDot,
            ],
          );
        },
      );
    } catch (_) {
      return fallback;
    }
  }
}

// Nút 3 chấm cho grid 2
class _Grid2MoreButton extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRefresh;
  const _Grid2MoreButton({
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_horiz, color: Colors.black54),
      tooltip: 'Tác vụ',
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.play_arrow, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              const Text('Phát'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          enabled: onEdit != null,
          child: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              const Text('Sửa'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 3,
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              const Text('Xóa'),
            ],
          ),
        ),
        if (onRefresh != null)
          PopupMenuItem(
            value: 4,
            child: Row(
              children: [
                Icon(Icons.refresh, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                const Text('Làm mới'),
              ],
            ),
          ),
      ],
      onSelected: (v) {
        if (v == 1) onPlay();
        if (v == 2 && onEdit != null) onEdit!();
        if (v == 3) onDelete();
        if (v == 4 && onRefresh != null) onRefresh!();
      },
    );
  }
}
