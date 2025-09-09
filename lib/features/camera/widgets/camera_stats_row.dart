import 'package:flutter/material.dart';

class CameraStatsRow extends StatelessWidget {
  const CameraStatsRow({
    super.key,
    this.abnormalCount = 0,
    this.offlineCount = 0,
    this.noStorageCount = 0,
    this.loading = false,
  });

  final int abnormalCount;
  final int offlineCount;
  final int noStorageCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              title: 'Thiết Bị Bất Thường',
              number: abnormalCount,
              loading: loading,
              icon: Icons.warning_amber_rounded,
              bg: scheme.errorContainer,
              fg: scheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              title: 'Ngoại tuyến',
              number: offlineCount,
              loading: loading,
              icon: Icons.wifi_off_rounded,
              bg: scheme.secondaryContainer,
              fg: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              title: 'Không Có Thiết Bị Lưu Trữ',
              number: noStorageCount,
              loading: loading,
              icon: Icons.sd_card_alert_rounded,
              bg: scheme.tertiaryContainer,
              fg: scheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.number,
    required this.title,
    required this.icon,
    required this.bg,
    required this.fg,
    this.loading = false,
  });
  final int number;
  final String title;
  final IconData icon;
  final Color bg;
  final Color fg;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Semantics(
      label: title,
      value: number.toString(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(bg.withValues(alpha: 0.18), surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: fg, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: loading
                        ? Container(
                            key: const ValueKey('loading'),
                            width: 44,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          )
                        : Text(
                            number.toString(),
                            key: ValueKey(number),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
