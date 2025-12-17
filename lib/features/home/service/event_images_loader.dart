import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/services/supabase_service.dart';
import 'package:detect_care_caregiver_app/services/event_image_cache_service.dart';

/// Wrapper for image sources (local file or network URL)
class ImageSource {
  final String path;

  ImageSource(this.path);

  /// Check if this is a local file path
  bool get isLocal => !path.startsWith('http');
}

final _snapshotUrlCache = <String, String>{};

Future<List<ImageSource>> loadEventImageUrls(EventLog log) async {
  AppLogger.d(
    '[EventImageLoader] ========== loadEventImageUrls called ==========',
  );
  AppLogger.d('[EventImageLoader] log.eventId=${log.eventId}');
  AppLogger.d(
    '[EventImageLoader] log.detectionData[snapshot_id]=${log.detectionData?['snapshot_id']}',
  );

  final urls = <String>[];
  final cacheService = EventImageCacheService();

  // If a specific snapshot_id is provided, include it in the cache key
  final overrideSnapshotId =
      (log.detectionData?['snapshot_id'] ?? log.contextData?['snapshot_id'])
          ?.toString();
  final cacheKey = (overrideSnapshotId != null && overrideSnapshotId.isNotEmpty)
      ? '${log.eventId}__snap_${overrideSnapshotId}'
      : log.eventId;

  final cachedPaths = await cacheService.getEventImages(cacheKey);
  if (cachedPaths.isNotEmpty) {
    AppLogger.d(
      '[EventImageLoader] Using ${cachedPaths.length} cached images for $cacheKey',
    );
    return cachedPaths.map((path) => ImageSource(path)).toList();
  }

  bool looksLikeUrl(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  void collect(dynamic node) {
    if (node is String && node.isNotEmpty && looksLikeUrl(node)) {
      urls.add(node.trim());
      return;
    }
    if (node is List) {
      for (final item in node) {
        collect(item);
      }
      return;
    }
    if (node is Map) {
      for (final value in node.values) {
        collect(value);
      }
    }
  }

  collect(log.detectionData);
  collect(log.contextData);
  collect(log.imageUrls);

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
    AppLogger.d(
      '[loadEventImageUrls] event=${log.eventId} candidateSnapshotIds=$ids',
    );
  } catch (_) {}

  if (ids.isNotEmpty || urls.isEmpty) {
    try {
      AppLogger.api(
        '[loadEventImageUrls] fetching event detail for ${log.eventId} to extract images (ids=${ids.length} urls_before=${urls.length})',
      );
      final ds = EventsRemoteDataSource();
      final detail = await ds.getEventById(eventId: log.eventId);
      final detailSnapshotId = detail['snapshot_id'] ?? detail['snapshotId'];
      if (detailSnapshotId is String && detailSnapshotId.isNotEmpty) {
        ids.add(detailSnapshotId);
      }
      {
        try {
          AppLogger.d(
            '[loadEventImageUrls] detail keys=${detail.keys.toList()}',
          );
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
      AppLogger.e('[loadEventImageUrls] error fetching event detail: $e');
      // ignore and continue
    }
  }

  if (ids.isNotEmpty) {
    final snapshotIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (snapshotIds.isNotEmpty) {
      final supabaseService = SupabaseService();
      for (final snapshotId in snapshotIds) {
        final cached = _snapshotUrlCache[snapshotId];
        if (cached != null && cached.isNotEmpty) {
          urls.add(cached);
          continue;
        }
        try {
          final url = await supabaseService.fetchSnapshotImageUrl(snapshotId);
          if (url != null && url.isNotEmpty) {
            urls.add(url);
            _snapshotUrlCache[snapshotId] = url;
          }
        } catch (e) {
          AppLogger.e(
            '[loadEventImageUrls] Supabase snapshot lookup failed for $snapshotId: $e',
          );
        }
      }
    }
  }

  final uniq = urls.toSet().toList();
  try {
    AppLogger.d(
      '[loadEventImageUrls] event=${log.eventId} found imageCount=${uniq.length}',
    );
    AppLogger.d('[loadEventImageUrls] URLs: $uniq');
    AppLogger.d(
      '[EventImageLoader] ========== loadEventImageUrls done ==========',
    );
  } catch (_) {}

  // Cache all images for future use (async, don't block return)
  if (uniq.isNotEmpty) {
    Future.wait(
      uniq.map(
        (url) => cacheService.cacheEventImage(eventId: cacheKey, imageUrl: url),
      ),
    ).catchError((e) {
      AppLogger.e('[EventImageLoader] Background cache failed: $e');
      return <String?>[];
    });
  }

  return uniq.map((url) => ImageSource(url)).toList();
}
