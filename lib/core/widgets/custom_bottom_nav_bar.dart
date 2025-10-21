import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Map<int, int> badgeCounts;

  final double height;
  final double iconSize;
  final double centerGap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double elevation;
  final double notchMargin;
  final MainAxisAlignment alignment;
  final double borderRadius;
  final double bottomMargin;
  final double horizontalMargin;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.badgeCounts = const {},
    this.height = 70,
    this.iconSize = 28,
    this.centerGap = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.color = Colors.white,
    this.elevation = 12,
    this.notchMargin = 8,
    this.alignment = MainAxisAlignment.spaceAround,
    this.borderRadius = 35,
    this.bottomMargin = 20,
    this.horizontalMargin = 20,
  }) : assert(height > 0),
       assert(iconSize > 0),
       assert(centerGap >= 0),
       assert(elevation >= 0),
       assert(notchMargin >= 0);

  @override
  Widget build(BuildContext context) {
    assert(
      (currentIndex >= 0 && currentIndex <= _navSpecs.length),
      'currentIndex $currentIndex is not a valid bottom nav index.',
    );

    // Build in two groups to leave a center gap for the FAB notch.
    final split = (_navSpecs.length / 2).ceil();
    final leftSpecs = _navSpecs.take(split).toList();
    final rightSpecs = _navSpecs.skip(split).toList();

    return Container(
      margin: EdgeInsets.only(
        left: horizontalMargin,
        right: horizontalMargin,
        bottom: bottomMargin,
      ),
      child: Material(
        elevation: elevation,
        borderRadius: BorderRadius.circular(borderRadius),
        color: color,
        shadowColor: Colors.black.withValues(alpha: 51),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: color,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: 242)],
            ),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 26),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: _buildFloatingBottomAppBar(context, leftSpecs, rightSpecs),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBottomAppBar(
    BuildContext context,
    List<_NavSpec> leftSpecs,
    List<_NavSpec> rightSpecs,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: FloatingNotchPainter(
              notchRadius: 30,
              notchMargin: notchMargin,
              backgroundColor: color,
              borderRadius: borderRadius,
            ),
          ),
          Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: alignment,
              children: [
                ...leftSpecs.map((s) => _buildItemButton(context, s)),
                SizedBox(width: centerGap),
                ...rightSpecs.map((s) => _buildItemButton(context, s)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemButton(BuildContext context, _NavSpec spec) {
    final isSelected = spec.index == currentIndex;
    final badgeCount = badgeCounts[spec.index] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Semantics(
        button: true,
        label: spec.tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Keep navigation consistent: notify parent to switch tab
            // instead of pushing a standalone screen which breaks the
            // app's global header/bottom layout.
            onTap(spec.index);
          },
          child: SizedBox(
            width: 64,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      spec.icon,
                      color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                      size: isSelected ? iconSize + 2 : iconSize,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      spec.tooltip,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Semantics(
                      label: badgeCount > 99
                          ? '99+ thông báo'
                          : '$badgeCount thông báo',
                      child: Container(
                        alignment: Alignment.center,
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerColor,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter để tạo notch floating
class FloatingNotchPainter extends CustomPainter {
  final double notchRadius;
  final double notchMargin;
  final Color backgroundColor;
  final double borderRadius;

  FloatingNotchPainter({
    required this.notchRadius,
    required this.notchMargin,
    required this.backgroundColor,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerX = size.width / 2;
    final notchTop = 0.0;

    path.moveTo(borderRadius, 0);
    path.lineTo(centerX - notchRadius - notchMargin, notchTop);
    path.arcToPoint(
      Offset(centerX + notchRadius + notchMargin, notchTop),
      radius: Radius.circular(notchRadius + notchMargin),
      clockwise: false,
    );
    path.lineTo(size.width - borderRadius, 0);
    path.arcToPoint(
      Offset(size.width, borderRadius),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(size.width, size.height - borderRadius);
    path.arcToPoint(
      Offset(size.width - borderRadius, size.height),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(borderRadius, size.height);
    path.arcToPoint(
      Offset(0, size.height - borderRadius),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(0, borderRadius);
    path.arcToPoint(
      Offset(borderRadius, 0),
      radius: Radius.circular(borderRadius),
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum BottomNavItem { home, camera, share_permissions, profile, patient }

class _NavSpec {
  final BottomNavItem item;
  final int index;
  final IconData icon;
  final String tooltip;
  const _NavSpec({
    required this.item,
    required this.index,
    required this.icon,
    required this.tooltip,
  });
}

const List<_NavSpec> _navSpecs = [
  _NavSpec(
    item: BottomNavItem.camera,
    index: 0,
    icon: Icons.video_library_rounded,
    tooltip: 'Camera',
  ),
  _NavSpec(
    item: BottomNavItem.share_permissions,
    index: 1,
    icon: Icons.group,
    tooltip: 'Thiết lập',
  ),
  _NavSpec(
    item: BottomNavItem.patient,
    index: 2,
    icon: Icons.favorite_outline,
    tooltip: 'Bệnh nhân',
  ),
  _NavSpec(
    item: BottomNavItem.profile,
    index: 3,
    icon: Icons.person_outline,
    tooltip: 'Hồ sơ',
  ),
];
