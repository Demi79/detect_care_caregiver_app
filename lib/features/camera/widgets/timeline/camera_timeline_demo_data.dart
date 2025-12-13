import 'package:flutter/material.dart';
import 'timeline_models.dart';

class DemoTimelineData {
  final List<CameraTimelineClip> clips;
  final List<CameraTimelineEntry> entries;

  DemoTimelineData({required this.clips, required this.entries});

  static DemoTimelineData generate(DateTime selectedDay) {
    final base = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final clips = [
      CameraTimelineClip(
        id: 'clip-210133',
        startTime: base.add(const Duration(hours: 21, minutes: 1, seconds: 33)),
        duration: const Duration(seconds: 24),
        accent: Colors.orange,
      ),
      CameraTimelineClip(
        id: 'clip-210109',
        startTime: base.add(const Duration(hours: 21, minutes: 1, seconds: 9)),
        duration: const Duration(seconds: 24),
        accent: Colors.blueGrey,
      ),
      CameraTimelineClip(
        id: 'clip-201732',
        startTime: base.add(
          const Duration(hours: 20, minutes: 17, seconds: 32),
        ),
        duration: const Duration(minutes: 2, seconds: 9),
        accent: Colors.blue,
      ),
      CameraTimelineClip(
        id: 'clip-201546',
        startTime: base.add(
          const Duration(hours: 20, minutes: 15, seconds: 46),
        ),
        duration: const Duration(minutes: 1, seconds: 16),
        accent: Colors.teal,
      ),
      CameraTimelineClip(
        id: 'clip-201345',
        startTime: base.add(
          const Duration(hours: 20, minutes: 13, seconds: 45),
        ),
        duration: const Duration(minutes: 1, seconds: 36),
        accent: Colors.deepOrange,
      ),
    ];

    final entries = [
      CameraTimelineEntry(
        time: base.add(const Duration(hours: 21)),
        clip: null,
      ),
      for (final clip in clips)
        CameraTimelineEntry(time: clip.startTime, clip: clip),
      CameraTimelineEntry(
        time: base.add(const Duration(hours: 20, minutes: 50)),
        clip: null,
      ),
      CameraTimelineEntry(
        time: base.add(const Duration(hours: 20, minutes: 40)),
        clip: null,
      ),
    ];

    return DemoTimelineData(clips: clips, entries: entries);
  }
}
