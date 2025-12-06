import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// Helper extension: withOpacity has been flagged by analyzer as deprecated in
// some SDKs; provide a safe helper that uses withAlpha under the hood to avoid
// precision-loss warnings while keeping intent clear.
extension ColorOpacitySafe on Color {
  Color withOpacitySafe(double opacity) {
    final a = (opacity * 255).round().clamp(0, 255);
    return withAlpha(a);
  }
}

/// Model describing a recorded clip item in the timeline.
class CameraTimelineClip {
  final String id;
  final DateTime startTime;
  final Duration duration;
  final Color accent;
  final String? cameraId;
  final String? playUrl;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final String? eventType;
  final Map<String, dynamic>? metadata;

  const CameraTimelineClip({
    required this.id,
    required this.startTime,
    required this.duration,
    required this.accent,
    this.cameraId,
    this.playUrl,
    this.downloadUrl,
    this.thumbnailUrl,
    this.eventType,
    this.metadata,
  });

  String get timeLabel {
    // Display times in UTC+7 (local Vietnam time) regardless of stored timezone.
    final tz = startTime.toUtc().add(const Duration(hours: 7));
    final h = tz.hour.toString().padLeft(2, '0');
    final m = tz.minute.toString().padLeft(2, '0');
    final s = tz.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get durationLabel {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return "${minutes.toString().padLeft(1, '0')}'${seconds.toString().padLeft(2, '0')}\"";
  }
}

/// Container for each timeline row.
class CameraTimelineEntry {
  final DateTime time;
  final CameraTimelineClip? clip;

  const CameraTimelineEntry({required this.time, this.clip});

  String get timeLabel {
    final tz = time.toUtc().add(const Duration(hours: 7));
    final h = tz.hour.toString().padLeft(2, '0');
    final m = tz.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class CameraTimelineModeOption {
  final IconData icon;
  final String label;

  const CameraTimelineModeOption(this.icon, this.label);
}

/// Small chip used by the mode selector row. Shows an icon and optional label.
class CameraTimelineModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  const CameraTimelineModeChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.orange.shade700 : Colors.transparent;
    final textColor = selected ? Colors.white : Colors.grey.shade800;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small circular button used in date selector and other compact controls.
class CameraTimelineCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const CameraTimelineCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.grey.shade100,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(icon, size: 20, color: Colors.grey.shade800),
          ),
        ),
      ),
    );
  }
}

/// A single row in the timeline list. It renders the left time label, the
/// vertical indicator and either a clip card or an empty placeholder.
class CameraTimelineRow extends StatelessWidget {
  final CameraTimelineEntry entry;
  final bool isSelected;
  final VoidCallback? onClipTap;

  const CameraTimelineRow({
    super.key,
    required this.entry,
    required this.isSelected,
    this.onClipTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasClip = entry.clip != null;
    const clipHeight = 96.0 + 16 + 10; // thumbnail + paddings

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, left: 6, right: 6),
            child: hasClip
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.orange.shade700
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.clip!.timeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : Text(
                    entry.timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 30,
          child: Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isSelected && hasClip
                      ? Colors.deepOrange
                      : Colors.grey.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    if (isSelected && hasClip)
                      BoxShadow(
                        color: Colors.orange.withOpacitySafe(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: clipHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade300, Colors.grey.shade200],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: hasClip
              ? CameraTimelineClipCard(
                  clip: entry.clip!,
                  selected: isSelected,
                  onTap: onClipTap,
                  showPlayButton: false,
                  showCameraIcon: false,
                )
              : CameraTimelineEmptyCard(timeLabel: entry.timeLabel),
        ),
      ],
    );
  }
}

class CameraTimelineClipCard extends StatelessWidget {
  final CameraTimelineClip clip;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final bool showPlayButton;
  final bool showCameraIcon;

  const CameraTimelineClipCard({
    super.key,
    required this.clip,
    required this.selected,
    this.onTap,
    this.onPlay,
    this.showPlayButton = true,
    this.showCameraIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12, right: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.deepOrange : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacitySafe(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: SizedBox(
                  height: 96,
                  child: Builder(
                    builder: (context) {
                      // compute gradient/decoration once per card to avoid repeated allocations
                      final gradient = LinearGradient(
                        colors: [
                          clip.accent.withOpacitySafe(0.9),
                          clip.accent.withOpacitySafe(0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      );

                      final placeholder = Container(
                        decoration: BoxDecoration(gradient: gradient),
                      );

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (clip.thumbnailUrl != null &&
                              clip.thumbnailUrl!.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: clip.thumbnailUrl!,
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => placeholder,
                              errorWidget: (ctx, url, error) {
                                debugPrint(
                                  '⚠️ Thumbnail load failed for $url: $error',
                                );
                                return placeholder;
                              },
                            )
                          else
                            placeholder,

                          // small overlay icon in the bottom-right
                          if (showCameraIcon)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  top: 8,
                                  right: 8,
                                  bottom: 8,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacitySafe(0.35),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacitySafe(
                                          0.18,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.videocam,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxBtn = math.min(96.0, constraints.maxWidth * 0.28);
                    final compactLocal = constraints.maxWidth < 150.0;
                    final screenWidth = MediaQuery.of(context).size.width;
                    // global breakpoint: compact when the whole screen is narrow
                    final compactGlobal = screenWidth < 360.0;
                    final useCompact = compactLocal || compactGlobal;
                    return Row(
                      children: [
                        Flexible(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clip.timeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (showPlayButton)
                          // animated switch between pill and icon-only using global breakpoint
                          PlayActionButton(
                            key: ValueKey(useCompact ? 'icon_only' : 'pill'),
                            useCompact: useCompact,
                            maxWidth: maxBtn,
                            onPressed: onPlay ?? onTap,
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
  }

  void _handleTap(BuildContext context) {
    onTap?.call();
    final url = clip.thumbnailUrl?.trim();
    if (url == null || url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).maybePop(),
        child: Dialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 48,
          ),
          child: Stack(
            children: [
              InteractiveViewer(
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (ctx, _) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (ctx, _, __) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact/reponsive play action used inside clip cards.
class PlayActionButton extends StatelessWidget {
  final bool useCompact;
  final double maxWidth;
  final VoidCallback? onPressed;

  const PlayActionButton({
    super.key,
    required this.useCompact,
    required this.maxWidth,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = Colors.orange.shade700;
    if (useCompact) {
      return SizedBox(
        width: 40,
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.orange.shade50,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.play_arrow, size: 18, color: Colors.orange),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: maxWidth,
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: accentColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Xem',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Removed per-card HEAD checks for performance; using CachedNetworkImage
// directly with placeholder/error fallback reduces extra network calls and
// simplifies behavior.

class CameraTimelineEmptyCard extends StatelessWidget {
  final String timeLabel;

  const CameraTimelineEmptyCard({super.key, required this.timeLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Icon(Icons.timelapse, color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khoảng trống $timeLabel',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Không có bản ghi trong khoảng thời gian này',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
