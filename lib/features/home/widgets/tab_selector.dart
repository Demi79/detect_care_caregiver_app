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
      key: 'highConfidence',
      label: 'Sự kiện',
      icon: Icons.warning_amber_rounded,
      color: AppTheme.warningColor,
    ),
    _TabConfig(
      key: 'lowConfidence',
      label: 'Nghi ngờ',
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
          height: 1.2,
        ) ??
        const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.2);

    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selectedConfig.color.withValues(alpha: 20),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final segWidth = (constraints.maxWidth - 8) / _tabs.length;
              final segments = _tabs.map((tab) {
                final bool isSelected = tab.key == selectedConfig.key;
                return ButtonSegment<String>(
                  value: tab.key,
                  label: SizedBox(
                    width: segWidth,
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon,
                          size: 18,
                          color: isSelected ? Colors.white : tab.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tab.label,
                          style: baseTextStyle.copyWith(
                            color: isSelected ? Colors.white : tab.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList();

              return SegmentedButton<String>(
                segments: segments,
                selected: {selectedConfig.key},
                showSelectedIcon: false,
                style: buttonStyle,
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    onTabChanged(selection.first);
                  }
                },
              );
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
