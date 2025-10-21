import 'dart:convert';

import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CameraStorage {
  static const String _storeKey = 'camera_entries';

  static const List<CameraEntry> defaultCameras = [
    CameraEntry(
      id: 'demo-1',
      name: 'DEMO',
      url:
          'rtsp://admin:L2C37340@192.168.8.122:554/cam/realmonitor?channel=1&subtype=1',
    ),
    CameraEntry(
      id: 'demo-2',
      name: 'demo222',
      url:
          'rtsp://admin:L2C37340@192.168.8.122:554/cam/realmonitor?channel=1&subtype=1',
    ),
    CameraEntry(
      id: 'demo-3',
      name: 'Ranger 2-L-4700',
      url:
          'rtsp://admin:L2C37340@192.168.8.122:554/cam/realmonitor?channel=1&subtype=1',
    ),
  ];

  static Future<List<CameraEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final arr = json.decode(raw) as List;
      return arr
          .map((e) => CameraEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<CameraEntry> cameras) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storeKey,
      json.encode(cameras.map((e) => e.toJson()).toList()),
    );
  }

  static Future<List<CameraEntry>> loadOrSeed({bool seedDemo = false}) async {
    var list = await load();
    if (seedDemo && list.isEmpty) {
      list = List.of(defaultCameras);
      await save(list);
    }
    return list;
  }
}
