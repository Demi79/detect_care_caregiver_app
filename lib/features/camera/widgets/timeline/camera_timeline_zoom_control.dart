import 'package:flutter/material.dart';
import 'camera_timeline_components.dart';

class CameraTimelineZoomControl extends StatelessWidget {
  final double zoomLevel;
  final ValueChanged<double> onAdjust;

  const CameraTimelineZoomControl({
    super.key,
    required this.zoomLevel,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacitySafe(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const buttonExtent = 48.0;
          final sliderHeight = (constraints.maxHeight - (buttonExtent * 2))
              .clamp(40.0, constraints.maxHeight);
          final knobTravel = (sliderHeight - 36).clamp(0.0, double.infinity);
          final knobTop = (1 - zoomLevel) * knobTravel;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => onAdjust(0.1),
              ),
              SizedBox(
                height: sliderHeight,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(
                      top: knobTop,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 26,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${(zoomLevel * 10).round()}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove, size: 20),
                onPressed: () => onAdjust(-0.1),
              ),
            ],
          );
        },
      ),
    );
  }
}
