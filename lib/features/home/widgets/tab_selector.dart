// import 'package:flutter/material.dart';
// import '../../../core/theme/app_theme.dart';

// class TabSelector extends StatelessWidget {
//   final String selectedTab;
//   final Function(String) onTabChanged;

//   const TabSelector({
//     super.key,
//     required this.selectedTab,
//     required this.onTabChanged,
//   });

//   // Each tab has an internal 'value' used by the app and a displayed 'label'.
//   // Keep internal values stable (english-like) to avoid breaking logic elsewhere.
//   final List<Map<String, dynamic>> tabs = const [
//     {
//       'value': 'warning',
//       'label': 'Cảnh báo',
//       'icon': Icons.warning_amber_rounded,
//       'color': AppTheme.warningColor,
//     },
//     {
//       'value': 'activity',
//       'label': 'Hoạt động',
//       'icon': Icons.monitor_heart_rounded,
//       'color': AppTheme.activityColor,
//     },
//     {
//       'value': 'report',
//       'label': 'Báo cáo',
//       'icon': Icons.assessment_rounded,
//       'color': AppTheme.reportColor,
//     },
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16),
//       padding: const EdgeInsets.all(4),
//       decoration: BoxDecoration(
//         color: AppTheme.unselectedBgColor,
//         borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
//         boxShadow: AppTheme.cardShadow,
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.max,
//         children: tabs.map((tab) {
//           final bool isSelected = tab['value'] == selectedTab;
//           final Color tabColor = tab['color'] as Color;

//           return Expanded(
//             child: LayoutBuilder(
//               builder: (context, constraints) => AnimatedContainer(
//                 duration: const Duration(milliseconds: 200),
//                 curve: Curves.easeInOut,
//                 width: constraints.maxWidth,
//                 child: Material(
//                   color: Colors.transparent,
//                   child: InkWell(
//                     onTap: () => onTabChanged(tab['value']),
//                     borderRadius: BorderRadius.circular(
//                       AppTheme.borderRadiusMedium,
//                     ),
//                     splashColor: tabColor.withValues(alpha: 0.1),
//                     highlightColor: tabColor.withValues(alpha: 0.05),
//                     child: AnimatedContainer(
//                       duration: const Duration(milliseconds: 200),
//                       curve: Curves.easeInOut,
//                       padding: const EdgeInsets.symmetric(
//                         vertical: 10,
//                         horizontal: 4,
//                       ),
//                       decoration: BoxDecoration(
//                         color: isSelected ? tabColor : Colors.transparent,
//                         borderRadius: BorderRadius.circular(
//                           AppTheme.borderRadiusMedium,
//                         ),
//                         boxShadow: isSelected
//                             ? [
//                                 BoxShadow(
//                                   color: tabColor.withValues(alpha: 0.3),
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 2),
//                                 ),
//                               ]
//                             : null,
//                       ),
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           AnimatedContainer(
//                             duration: const Duration(milliseconds: 200),
//                             child: Icon(
//                               tab['icon'] as IconData,
//                               color: isSelected
//                                   ? AppTheme.selectedTextColor
//                                   : tabColor,
//                               size: 20,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           AnimatedDefaultTextStyle(
//                             duration: const Duration(milliseconds: 200),
//                             style: TextStyle(
//                               color: isSelected
//                                   ? AppTheme.selectedTextColor
//                                   : AppTheme.unselectedTextColor,
//                               fontWeight: isSelected
//                                   ? FontWeight.w600
//                                   : FontWeight.w500,
//                               fontSize: 11,
//                               letterSpacing: 0.2,
//                             ),
//                             child: Text(
//                               tab['label'],
//                               textAlign: TextAlign.center,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class TabSelector extends StatelessWidget {
  final String selectedTab;
  final ValueChanged<String> onTabChanged;

  const TabSelector({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  static const List<_TabConfig> _tabs = [
    _TabConfig(
      key: 'warning',
      label: 'Cảnh báo',
      icon: Icons.warning_amber_rounded,
      color: AppTheme.warningColor,
    ),
    _TabConfig(
      key: 'activity',
      label: 'Hoạt động',
      icon: Icons.event_available_rounded,
      color: AppTheme.activityColor,
    ),
    _TabConfig(
      key: 'report',
      label: 'Báo cáo',
      icon: Icons.insert_chart_outlined,
      color: AppTheme.reportColor,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedConfig = _tabs.firstWhere(
      (tab) => tab.key == selectedTab,
      orElse: () => _tabs.first,
    );

    final baseTextStyle =
        Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ) ??
        const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.25,
        );

    final segments = _tabs.map((tab) {
      final bool isSelected = tab.key == selectedConfig.key;
      return ButtonSegment<String>(
        value: tab.key,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab.icon,
              size: 16,
              color: isSelected ? Colors.white : tab.color,
            ),
            const SizedBox(width: 6),
            Text(
              tab.label,
              style: baseTextStyle.copyWith(
                color: isSelected ? Colors.white : tab.color,
              ),
            ),
          ],
        ),
      );
    }).toList();

    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return selectedConfig.color;
        }
        return cs.surface;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return cs.onSurfaceVariant;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return BorderSide(color: selectedConfig.color, width: 1.2);
        }
        return BorderSide(color: cs.outlineVariant);
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return selectedConfig.color.withValues(
            alpha: states.contains(WidgetState.pressed) ? 46 : 31,
          );
        }
        if (states.contains(WidgetState.pressed)) {
          return cs.primary.withValues(alpha: 31);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return cs.primary.withValues(alpha: 20);
        }
        return Colors.transparent;
      }),
      elevation: const WidgetStatePropertyAll(0),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selectedConfig.color.withValues(alpha: 20),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SegmentedButton<String>(
            segments: segments,
            selected: {selectedConfig.key},
            showSelectedIcon: false,
            style: buttonStyle,
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                onTabChanged(selection.first);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _TabConfig {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const _TabConfig({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}
