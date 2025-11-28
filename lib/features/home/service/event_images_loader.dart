import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';

Future<List<String>> loadEventImageUrls(EventLog log) async {
  final urls = <String>[];

  void take(dynamic v) {
    if (v is String && v.isNotEmpty) {
      urls.add(v);
    }
    if (v is List) {
      for (final e in v) {
        if (e is String && e.isNotEmpty) {
          urls.add(e);
        }
      }
    }
  }

  take(log.detectionData['cloud_url']);
  take(log.detectionData['cloud_urls']);
  take(log.contextData['cloud_url']);
  take(log.contextData['cloud_urls']);
  take(log.imageUrls);

  final ids = <String>[];
  final cands = [
    log.detectionData['snapshot_id'],
    log.contextData['snapshot_id'],
    log.detectionData['snapshot_ids'],
    log.contextData['snapshot_ids'],
  ];
  for (final v in cands) {
    if (v is String && v.isNotEmpty) {
      ids.add(v);
    }
    if (v is List) {
      for (final e in v) {
        if (e is String && e.isNotEmpty) {
          ids.add(e);
        }
      }
    }
  }

  // Debug: show candidate snapshot ids we found (if any)
  try {
    print(
      '[loadEventImageUrls] event=${log.eventId} candidateSnapshotIds=$ids',
    );
  } catch (_) {}

  // If we found snapshot ids, or we didn't find any direct URLs on the
  // EventLog (urls.isEmpty), fetch the full event detail and try to extract
  // image URLs from snapshots/files and snapshot_url. This covers cases
  // where the feed item doesn't include the files but the detail does.
  if (ids.isNotEmpty || urls.isEmpty) {
    // The snapshots API was removed; fetch the full event detail and
    // extract snapshot.files[].cloud_url or snapshot_url from the detail
    try {
      print(
        '[loadEventImageUrls] fetching event detail for ${log.eventId} to extract images (ids=${ids.length} urls_before=${urls.length})',
      );
      final ds = EventsRemoteDataSource();
      final detail = await ds.getEventById(eventId: log.eventId);
      {
        try {
          print('[loadEventImageUrls] detail keys=${detail.keys.toList()}');
        } catch (_) {}
        // snapshot_url
        final sv = detail['snapshot_url'] ?? detail['snapshotUrl'];
        if (sv is String && sv.isNotEmpty) urls.add(sv);

        // snapshots or snapshot objects
        final snaps = detail['snapshots'] ?? detail['snapshot'];
        if (snaps != null) {
          if (snaps is Map) {
            if (snaps.containsKey('files') && snaps['files'] is List) {
              for (final f in (snaps['files'] as List)) {
                if (f is Map && (f['cloud_url'] ?? f['url']) != null) {
                  final u = (f['cloud_url'] ?? f['url']).toString();
                  if (u.isNotEmpty) urls.add(u);
                }
              }
            } else if ((snaps['cloud_url'] ?? snaps['url']) != null) {
              urls.add((snaps['cloud_url'] ?? snaps['url']).toString());
            }
          } else if (snaps is List) {
            for (final s in snaps) {
              if (s is Map) {
                if (s.containsKey('files') && s['files'] is List) {
                  for (final f in (s['files'] as List)) {
                    if (f is Map && (f['cloud_url'] ?? f['url']) != null) {
                      final u = (f['cloud_url'] ?? f['url']).toString();
                      if (u.isNotEmpty) urls.add(u);
                    }
                  }
                } else if ((s['cloud_url'] ?? s['url']) != null) {
                  urls.add((s['cloud_url'] ?? s['url']).toString());
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('[loadEventImageUrls] error fetching event detail: $e');
      // ignore and continue
    }
  }

  final uniq = urls.toSet().toList();
  try {
    print(
      '[loadEventImageUrls] event=${log.eventId} found imageCount=${uniq.length}',
    );
  } catch (_) {}
  return uniq;
}
