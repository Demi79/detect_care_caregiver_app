import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TabSelector extends StatelessWidget {
  final String selectedTab;
  final Function(String) onTabChanged;

  const TabSelector({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final List<Map<String, dynamic>> tabs = const [
    {
      'label': 'Warning',
      'icon': Icons.warning_amber_rounded,
      'color': AppTheme.warningColor,
    },
    {
      'label': 'Activity',
      'icon': Icons.monitor_heart_rounded,
      'color': AppTheme.activityColor,
    },
    {
      'label': 'Report',
      'icon': Icons.assessment_rounded,
      'color': AppTheme.reportColor,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.unselectedBgColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: tabs.map((tab) {
          final bool isSelected = tab['label'] == selectedTab;
          final Color tabColor = tab['color'] as Color;

          return Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: constraints.maxWidth,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTabChanged(tab['label']),
                    borderRadius: BorderRadius.circular(
                      AppTheme.borderRadiusMedium,
                    ),
                    splashColor: tabColor.withValues(alpha: 0.1),
                    highlightColor: tabColor.withValues(alpha: 0.05),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? tabColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusMedium,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: tabColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              tab['icon'] as IconData,
                              color: isSelected
                                  ? AppTheme.selectedTextColor
                                  : tabColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color: isSelected
                                  ? AppTheme.selectedTextColor
                                  : AppTheme.unselectedTextColor,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 11,
                              letterSpacing: 0.2,
                            ),
                            child: Text(
                              tab['label'],
                              textAlign: TextAlign.center,
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
        }).toList(),
      ),
    );
  }
}
