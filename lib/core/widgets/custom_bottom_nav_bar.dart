import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

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
      (currentIndex >= 0 && currentIndex < _navSpecs.length) ||
          currentIndex == 4,
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
        shadowColor: Colors.black.withOpacity(0.2),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: color,
            // Thêm gradient để tạo hiệu ứng đẹp hơn
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withOpacity(0.95)],
            ),
            // Thêm border subtle để tạo độ sâu
            border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: _buildFloatingBottomAppBar(leftSpecs, rightSpecs),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBottomAppBar(
    List<_NavSpec> leftSpecs,
    List<_NavSpec> rightSpecs,
  ) {
    return Container(
      decoration: BoxDecoration(
        // Notch shape cho floating design
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        children: [
          // Background với notch
          CustomPaint(
            size: Size.infinite,
            painter: FloatingNotchPainter(
              notchRadius: 30,
              notchMargin: notchMargin,
              backgroundColor: color,
              borderRadius: borderRadius,
            ),
          ),
          // Navigation items
          Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: alignment,
              children: [
                ...leftSpecs.map(_buildItemButton),
                SizedBox(width: centerGap),
                ...rightSpecs.map(_buildItemButton),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemButton(_NavSpec spec) {
    final isSelected = spec.index == currentIndex;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isSelected
            ? AppTheme.primaryBlue.withOpacity(0.1)
            : Colors.transparent,
      ),
      child: IconButton(
        key: ValueKey('bottom-item-${spec.index}-${spec.item.name}'),
        tooltip: spec.tooltip,
        onPressed: () => onTap(spec.index),
        icon: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Icon(
            spec.icon,
            color: isSelected ? AppTheme.primaryBlue : Colors.grey,
            size: isSelected ? iconSize + 2 : iconSize,
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

    // Vẽ path với notch
    path.moveTo(borderRadius, 0);

    // Đi đến điểm bắt đầu notch
    path.lineTo(centerX - notchRadius - notchMargin, notchTop);

    // Tạo notch cong
    path.arcToPoint(
      Offset(centerX + notchRadius + notchMargin, notchTop),
      radius: Radius.circular(notchRadius + notchMargin),
      clockwise: false,
    );

    // Hoàn thành phần còn lại
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

/// Logical destinations for the bottom bar.
enum BottomNavItem { home, camera, search, notifications, profile, patient }

/// Presentation spec for a destination (icon, tooltip, index).
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

// Keep the visual order and index mapping in one place.
const List<_NavSpec> _navSpecs = [
  _NavSpec(
    item: BottomNavItem.camera,
    index: 0,
    icon: Icons.video_library_rounded,
    tooltip: 'Camera',
  ),
  _NavSpec(
    item: BottomNavItem.search,
    index: 1,
    icon: Icons.search_outlined,
    tooltip: 'Search',
  ),
  _NavSpec(
    item: BottomNavItem.notifications,
    index: 2,
    icon: Icons.notifications_outlined,
    tooltip: 'Notifications',
  ),
  _NavSpec(
    item: BottomNavItem.profile,
    index: 3,
    icon: Icons.person_outline,
    tooltip: 'Profile',
  ),
];
