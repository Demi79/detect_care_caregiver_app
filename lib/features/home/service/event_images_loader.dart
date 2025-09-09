import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/home/models/log_entry.dart';
import 'package:detect_care_caregiver_app/features/snapshots/data/snapshots_remote_data_source.dart';

Future<List<String>> loadEventImageUrls(EventLog log) async {
  final urls = <String>[];

  void take(dynamic v) {
    if (v is String && v.isNotEmpty) urls.add(v);
    if (v is List) {
      for (final e in v) if (e is String && e.isNotEmpty) urls.add(e);
    }
  }

  take(log.detectionData['cloud_url']);
  take(log.detectionData['cloud_urls']);
  take(log.contextData['cloud_url']);
  take(log.contextData['cloud_urls']);

  final ids = <String>[];
  final cands = [
    log.detectionData['snapshot_id'],
    log.contextData['snapshot_id'],
    log.detectionData['snapshot_ids'],
    log.contextData['snapshot_ids'],
  ];
  for (final v in cands) {
    if (v is String && v.isNotEmpty) ids.add(v);
    if (v is List) {
      for (final e in v) if (e is String && e.isNotEmpty) ids.add(e);
    }
  }

  if (ids.isNotEmpty) {
    final ds = SnapshotsRemoteDataSource();
    final snaps = await ds.getManyByIds(ids);
    for (final s in snaps) {
      if (s.cloudUrl != null && s.cloudUrl!.isNotEmpty) {
        urls.add(s.cloudUrl!);
      } else if (s.imagePath != null && s.imagePath!.isNotEmpty) {
        urls.add(s.imagePath!);
      }
    }
  }

  return urls.toSet().toList();
}
