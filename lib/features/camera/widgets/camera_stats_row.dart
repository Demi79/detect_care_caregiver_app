import 'package:flutter/material.dart';

class _StatTile extends StatefulWidget {
  const _StatTile({
    required this.number,
    required this.title,
    required this.icon,
    required this.bg,
    required this.fg,
    this.loading = false,
    this.onTap,
  });

  final int number;
  final String title;
  final IconData icon;
  final Color bg;
  final Color fg;
  final bool loading;
  final VoidCallback? onTap;

  @override
  State<_StatTile> createState() => _StatTileState();
}

class CameraStatsRow extends StatelessWidget {
  const CameraStatsRow({
    super.key,
    required this.abnormalCount,
    required this.offlineCount,
    required this.noStorageCount,
    this.loading = false,
    this.onAbnormalTap,
    this.onOfflineTap,
    this.onNoStorageTap,
  });

  final int abnormalCount;
  final int offlineCount;
  final int noStorageCount;
  final bool loading;
  final VoidCallback? onAbnormalTap;
  final VoidCallback? onOfflineTap;
  final VoidCallback? onNoStorageTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              number: abnormalCount,
              title: 'Báo động',
              icon: Icons.warning_amber_rounded,
              bg: Colors.orange.shade50,
              fg: Colors.orange,
              loading: loading,
              onTap: onAbnormalTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              number: offlineCount,
              title: 'Ngoại tuyến',
              icon: Icons.cloud_off_rounded,
              bg: Colors.red.shade50,
              fg: Colors.red,
              loading: loading,
              onTap: onOfflineTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              number: noStorageCount,
              title: 'Không có thẻ',
              icon: Icons.sd_card_alert_rounded,
              bg: Colors.grey.shade100,
              fg: Colors.black54,
              loading: loading,
              onTap: onNoStorageTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTileState extends State<_StatTile> {
  bool _hover = false;

  void _setHover(bool v) {
    if (_hover == v) return;
    setState(() => _hover = v);
  }

  @override
  Widget build(BuildContext context) {
    final highlight = widget.number > 0;
    final scale = _hover ? 1.01 : 1.0;

    String formatNumber(int n) {
      // simple thousands separator
      final s = n.toString();
      final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
      return s.replaceAllMapped(reg, (m) => ',');
    }

    return Semantics(
      label: widget.title,
      value: widget.number.toString(),
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.identity()..scale(scale, scale),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight
                  ? Colors.blueAccent.withAlpha((0.16 * 255).round())
                  : Colors.grey.withAlpha((0.08 * 255).round()),
              width: highlight ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(
                  ((_hover ? 0.06 : 0.03) * 255).round(),
                ),
                blurRadius: _hover ? 10 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Tooltip(
            message: '${widget.title}: ${formatNumber(widget.number)}',
            preferBelow: false,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: widget.onTap,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.bg.withAlpha((0.95 * 255).round()),
                            widget.bg,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.06 * 255).round()),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, color: widget.fg, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: widget.loading
                                ? Container(
                                    key: const ValueKey('loading'),
                                    width: 72,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        width: 40,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    formatNumber(widget.number),
                                    key: ValueKey(widget.number),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: highlight
                                          ? Colors.blueAccent
                                          : Colors.black87,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
