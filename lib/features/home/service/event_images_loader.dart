import 'package:detect_care_caregiver_app/core/utils/logger.dart';
import 'package:detect_care_caregiver_app/features/home/models/event_log.dart';
import 'package:detect_care_caregiver_app/features/events/data/events_remote_data_source.dart';
import 'package:detect_care_caregiver_app/services/supabase_service.dart';
import 'package:detect_care_caregiver_app/services/event_image_cache_service.dart';
import 'dart:async';

/// Wrapper for image sources (local file or network URL)
class ImageSource {
  final String path;

  ImageSource(this.path);

  /// Check if this is a local file path
  bool get isLocal => !path.startsWith('http');
}

final _snapshotUrlCache = <String, String>{};

Future<List<ImageSource>> loadEventImageUrls(
  EventLog log, {
  bool bypassCache = false,
  bool preferCancelSnapshots = false,
}) async {
  final urls = <String>[];
  final cancelUrls = <String>[];
  final cacheService = EventImageCacheService();

  final canonicalEventId = log.eventId.trim();
  bool isUuidLoose(String s) {
    final v = s.trim();
    final r = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return r.hasMatch(v);
  }

  final eventIdIsCanonical =
      canonicalEventId.isNotEmpty && isUuidLoose(canonicalEventId);

  bool isCanceled(String? value) {
    final v = value?.toLowerCase().trim();
    if (v == null || v.isEmpty) return false;
    return v.contains('cancel');
  }

  bool looksLikeUrl(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  void collectFromMap(Map? m) {
    if (m == null) return;
    final candidates = <String>[];
    void addIfUrl(dynamic v) {
      if (v is String && v.trim().isNotEmpty && looksLikeUrl(v)) {
        candidates.add(v.trim());
      }
    }

    // Check for snapshot_images array with index (API response format)
    final snapImages = m['snapshot_images'] ?? m['snapshotImages'];
    if (snapImages is List && snapImages.isNotEmpty) {
      // Sort by index to maintain order
      final sorted = List<Map>.from(snapImages.whereType<Map>());
      sorted.sort((a, b) {
        final idxA = a['index'] is int ? a['index'] as int : -1;
        final idxB = b['index'] is int ? b['index'] as int : -1;
        return idxA.compareTo(idxB);
      });
      for (final img in sorted) {
        addIfUrl(img['cloud_url'] ?? img['url']);
      }
      urls.addAll(candidates);
      return; // Priority: use snapshot_images if available
    }

    addIfUrl(m['snapshot_url'] ?? m['snapshotUrl']);
    final svs = m['snapshot_urls'] ?? m['snapshotUrls'];
    if (svs is String) addIfUrl(svs);
    if (svs is List) {
      for (final s in svs) addIfUrl(s);
    }

    addIfUrl(m['cloud_url'] ?? m['cloudUrl']);
    final cvs = m['cloud_urls'] ?? m['cloudUrls'];
    if (cvs is String) addIfUrl(cvs);
    if (cvs is List) {
      for (final c in cvs) addIfUrl(c);
    }

    addIfUrl(m['image_url'] ?? m['imageUrl']);
    final ivs = m['image_urls'] ?? m['imageUrls'];
    if (ivs is String) addIfUrl(ivs);
    if (ivs is List) {
      for (final i in ivs) addIfUrl(i);
    }

    final snaps = m['snapshots'] ?? m['snapshot'];
    if (snaps is Map) {
      addIfUrl(snaps['cloud_url'] ?? snaps['url']);
      // Preserve order of files array
      if (snaps['files'] is List) {
        for (final f in snaps['files']) {
          if (f is Map) addIfUrl(f['cloud_url'] ?? f['url']);
        }
      }
    } else if (snaps is List) {
      for (final s in snaps) {
        if (s is Map) {
          addIfUrl(s['cloud_url'] ?? s['url']);
          if (s['files'] is List) {
            for (final f in s['files']) {
              if (f is Map) addIfUrl(f['cloud_url'] ?? f['url']);
            }
          }
        }
      }
    }

    urls.addAll(candidates);
  }

  void collectCancelUrls(Map? m) {
    if (m == null) return;
    void addIfUrl(dynamic v) {
      if (v is String && v.trim().isNotEmpty && looksLikeUrl(v)) {
        cancelUrls.add(v.trim());
      }
    }

    final cancelList = m['cancel_snapshot_urls'] ?? m['cancelSnapshotUrls'];
    if (cancelList is String) addIfUrl(cancelList);
    if (cancelList is List) {
      for (final c in cancelList) addIfUrl(c);
    }
    addIfUrl(m['cancel_snapshot_url'] ?? m['cancelSnapshotUrl']);
  }

  void collectFromImageUrls(dynamic img) {
    if (img == null) return;
    if (img is String && looksLikeUrl(img)) urls.add(img.trim());
    if (img is List) {
      for (final it in img) {
        if (it is String && looksLikeUrl(it)) urls.add(it.trim());
      }
    }
    if (img is Map) {
      for (final v in img.values) {
        if (v is String && looksLikeUrl(v)) urls.add(v.trim());
      }
    }
  }

  void collectSnapshotIds(List<String> dest, dynamic value) {
    if (value == null) return;
    if (value is String && value.trim().isNotEmpty) {
      dest.add(value.trim());
      return;
    }
    if (value is List) {
      for (final it in value) {
        if (it is String && it.trim().isNotEmpty) {
          dest.add(it.trim());
        }
      }
    }
  }

  collectFromMap(log.detectionData);
  collectFromMap(log.contextData);
  collectFromImageUrls(log.imageUrls);
  if (preferCancelSnapshots) {
    collectCancelUrls(log.detectionData);
    collectCancelUrls(log.contextData);
  }

  final logCanceled = isCanceled(log.lifecycleState) || isCanceled(log.status);
  final allowCache = !bypassCache && (!logCanceled || cancelUrls.isEmpty);

  if (preferCancelSnapshots && logCanceled && cancelUrls.isNotEmpty) {
    return cancelUrls.toSet().map((url) => ImageSource(url)).toList();
  }

  final ids = <String>[];
  final snapshotCandidates = [
    log.detectionData['snapshot_id'],
    log.contextData['snapshot_id'],
    log.detectionData['snapshotId'],
    log.contextData['snapshotId'],
    log.detectionData['snapshot_ids'],
    log.contextData['snapshot_ids'],
    log.detectionData['snapshotIds'],
    log.contextData['snapshotIds'],
  ];
  for (final candidate in snapshotCandidates) {
    collectSnapshotIds(ids, candidate);
  }

  try {
    AppLogger.d(
      '[loadEventImageUrls] event=${log.eventId} candidateSnapshotIds=$ids',
    );
  } catch (_) {}

  if (eventIdIsCanonical &&
      (ids.isNotEmpty ||
          urls.isEmpty ||
          (preferCancelSnapshots && logCanceled))) {
    try {
      AppLogger.api(
        '[loadEventImageUrls] fetching event detail for $canonicalEventId to extract images (ids=${ids.length} urls_before=${urls.length})',
      );
      final ds = EventsRemoteDataSource();
      final detail = await ds.getEventById(eventId: canonicalEventId);
      final detailSnapshotId = detail['snapshot_id'] ?? detail['snapshotId'];
      if (detailSnapshotId is String && detailSnapshotId.isNotEmpty) {
        ids.add(detailSnapshotId.trim());
      }
      try {
        AppLogger.d('[loadEventImageUrls] detail keys=${detail.keys.toList()}');
      } catch (_) {}

      final detailCanceled =
          isCanceled(
            (detail['lifecycle_state'] ?? detail['lifecycleState'])?.toString(),
          ) ||
          isCanceled((detail['status'] ?? detail['new_status'])?.toString());
      if (preferCancelSnapshots && detailCanceled) {
        collectCancelUrls(detail);
      }

      final sv = detail['snapshot_url'] ?? detail['snapshotUrl'];
      if (sv is String && sv.isNotEmpty && looksLikeUrl(sv)) {
        urls.add(sv);
      }

      // Prefer snapshot_images with index if available
      final snapImages = detail['snapshot_images'] ?? detail['snapshotImages'];
      if (snapImages is List && snapImages.isNotEmpty) {
        final sorted = List<Map>.from(snapImages.whereType<Map>());
        sorted.sort((a, b) {
          final idxA = a['index'] is int ? a['index'] as int : -1;
          final idxB = b['index'] is int ? b['index'] as int : -1;
          return idxA.compareTo(idxB);
        });
        for (final img in sorted) {
          final u = (img['cloud_url'] ?? img['url'])?.toString();
          if (u != null && u.isNotEmpty && looksLikeUrl(u)) urls.add(u);
        }
      } else {
        // Fallback to snapshots structure
        final snaps = detail['snapshots'] ?? detail['snapshot'];
        if (snaps != null) {
          if (snaps is Map) {
            if (snaps.containsKey('files') && snaps['files'] is List) {
              // Preserve files array order
              for (final f in (snaps['files'] as List)) {
                if (f is Map && (f['cloud_url'] ?? f['url']) != null) {
                  final u = (f['cloud_url'] ?? f['url']).toString();
                  if (u.isNotEmpty && looksLikeUrl(u)) urls.add(u);
                }
              }
            } else if ((snaps['cloud_url'] ?? snaps['url']) != null) {
              final u = (snaps['cloud_url'] ?? snaps['url']).toString();
              if (u.isNotEmpty && looksLikeUrl(u)) urls.add(u);
            }
          } else if (snaps is List) {
            for (final s in snaps) {
              if (s is Map) {
                if (s.containsKey('files') && s['files'] is List) {
                  for (final f in (s['files'] as List)) {
                    if (f is Map && (f['cloud_url'] ?? f['url']) != null) {
                      final u = (f['cloud_url'] ?? f['url']).toString();
                      if (u.isNotEmpty && looksLikeUrl(u)) urls.add(u);
                    }
                  }
                } else if ((s['cloud_url'] ?? s['url']) != null) {
                  final u = (s['cloud_url'] ?? s['url']).toString();
                  if (u.isNotEmpty && looksLikeUrl(u)) urls.add(u);
                }
              }
            }
          }
        }
      }

      if (preferCancelSnapshots && detailCanceled && cancelUrls.isNotEmpty) {
        // Preserve cancelUrls order while deduping
        final uniqCancel = <String>[];
        final _seenCancel = <String>{};
        for (final url in cancelUrls) {
          if (url.trim().isEmpty) continue;
          if (_seenCancel.add(url)) uniqCancel.add(url);
        }
        if (eventIdIsCanonical && uniqCancel.isNotEmpty) {
          Future.wait(
            uniqCancel.map(
              (url) => cacheService.cacheEventImage(
                eventId: canonicalEventId,
                imageUrl: url,
              ),
            ),
          ).catchError((e) {
            AppLogger.e('[EventImageLoader] cancel cache failed: $e');
            return <String?>[];
          });
        }
        return uniqCancel.map((url) => ImageSource(url)).toList();
      }
    } catch (e) {
      AppLogger.e('[loadEventImageUrls] error fetching event detail: $e');
    }
  }

  // Removed duplicate cache check - already checked at top

  if (ids.isNotEmpty) {
    final snapshotIds = <String>[];
    final _seenIds = <String>{};
    for (final id in ids) {
      final tid = id.trim();
      if (tid.isEmpty) continue;
      if (_seenIds.add(tid)) snapshotIds.add(tid);
    }
    final supabaseService = SupabaseService();
    if (allowCache) {
      for (final snapshotId in snapshotIds) {
        try {
          final cachedSnapPaths = await cacheService.getSnapshotImages(
            snapshotId,
          );
          if (cachedSnapPaths.isNotEmpty) {
            AppLogger.d(
              '[EventImageLoader] Using ${cachedSnapPaths.length} cached snapshot images for $snapshotId',
            );
            return cachedSnapPaths.map((p) => ImageSource(p)).toList();
          }
        } catch (_) {}
      }
    }

    for (final snapshotId in snapshotIds) {
      if (allowCache) {
        final cached = _snapshotUrlCache[snapshotId];
        if (cached != null && cached.isNotEmpty) {
          urls.add(cached);
          continue;
        }
      }
      try {
        final url = await supabaseService.fetchSnapshotImageUrl(snapshotId);
        if (url != null && url.isNotEmpty) {
          urls.add(url);
          _snapshotUrlCache[snapshotId] = url;
          cacheService.cacheSnapshotImage(
            snapshotId: snapshotId,
            imageUrl: url,
          );
        }
      } catch (e) {
        AppLogger.e(
          '[loadEventImageUrls] Supabase snapshot lookup failed for $snapshotId: $e',
        );
      }
    }
  }

  final uniq = <String>[];
  final _seen = <String>{};
  for (final u in urls) {
    final tu = u.trim();
    if (tu.isEmpty) continue;
    if (_seen.add(tu)) uniq.add(tu);
  }
  try {
    AppLogger.d(
      '[loadEventImageUrls] event=${log.eventId} found imageCount=${uniq.length}',
    );
  } catch (_) {}

  if (eventIdIsCanonical && uniq.isNotEmpty) {
    // Cache all images as a batch to preserve order
    final urlsToCache = uniq;
    Future.forEach<String>(urlsToCache, (url) async {
      try {
        await cacheService.cacheEventImage(
          eventId: canonicalEventId,
          imageUrl: url,
        );
      } catch (e) {
        AppLogger.e('[EventImageLoader] Cache failed for $url: $e');
      }
    }).catchError((e) {
      AppLogger.e('[EventImageLoader] Batch cache failed: $e');
    });
  }

  return uniq.map((url) => ImageSource(url)).toList();
}
