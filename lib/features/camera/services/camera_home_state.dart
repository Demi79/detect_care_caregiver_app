import 'dart:async';

import 'package:detect_care_caregiver_app/features/camera/data/camera_storage.dart';
import 'package:detect_care_caregiver_app/features/camera/models/camera_entry.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_quota_service.dart';
import 'package:detect_care_caregiver_app/features/camera/services/camera_service.dart';
import 'package:flutter/material.dart';

class CameraHomeState extends ChangeNotifier {
  final CameraService _cameraService;
  final CameraQuotaService _quotaService;

  List<CameraEntry> _cameras = [];
  bool _loading = true;
  bool _refreshing = false;
  String _search = '';
  bool _grid = true;
  bool _sortAsc = true;
  DateTime? _lastRefreshed;

  CameraQuotaValidationResult? _quotaValidation;

  final Map<String, Timer> _pendingDeleteTimers = {};
  final Map<String, CameraEntry> _pendingDeletedEntries = {};
  Timer? _searchDebounceTimer;

  bool _isDisposed = false;

  List<CameraEntry> get cameras => _cameras;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  String get search => _search;
  bool get grid => _grid;
  bool get sortAsc => _sortAsc;
  DateTime? get lastRefreshed => _lastRefreshed;
  CameraQuotaValidationResult? get quotaValidation => _quotaValidation;

  List<CameraEntry> get filteredCameras =>
      _cameraService.filterAndSortCameras(_cameras, _search, _sortAsc);

  CameraHomeState(this._cameraService, this._quotaService);

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> loadCameras() async {
    if (_isDisposed) return;

    debugPrint('[CameraHomeState] loadCameras() start');
    _loading = true;
    notifyListeners();

    // 1) Quick: load cached/seeded cameras to show UI immediately
    try {
      final cached = await CameraStorage.loadOrSeed();
      debugPrint('[CameraHomeState] cached cameras: ${cached.length}');
      if (cached.isNotEmpty && !_isDisposed) {
        _cameras = cached;
        _loading = false;
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('[CameraHomeState] Error loading cached cameras: $e\n$st');
    }

    // 2) Fetch remote cameras and update state & cache
    try {
      // Add a short timeout so a hung network request won't keep the UI stuck
      final remote = await _cameraService.loadCameras().timeout(
        const Duration(seconds: 6),
      );
      debugPrint('[CameraHomeState] remote cameras: ${remote.length}');
      if (!_isDisposed) {
        _cameras = remote;
        _lastRefreshed = DateTime.now();
        try {
          await CameraStorage.save(_cameras);
        } catch (saveErr) {
          debugPrint('[CameraHomeState] failed to save cache: $saveErr');
        }
      }
    } on TimeoutException catch (t) {
      debugPrint('[CameraHomeState] remote fetch timed out: $t');
    } catch (e, st) {
      debugPrint('[CameraHomeState] Error loading cameras: $e\n$st');
    } finally {
      if (!_isDisposed) {
        _loading = false;
        debugPrint(
          '[CameraHomeState] loadCameras() finished, cameras=${_cameras.length}',
        );
        notifyListeners();

        await validateCameraQuota();
      }
    }
  }

  Future<void> addCamera(Map<String, dynamic> cameraData) async {
    try {
      final newCamera = await _cameraService.createCamera(cameraData);
      if (_isDisposed) return;

      _cameras.add(newCamera);

      await validateCameraQuota();

      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to add camera: $e');
    }
  }

  Future<void> updateCamera(
    String cameraId,
    Map<String, dynamic> cameraData,
  ) async {
    try {
      final updated = await _cameraService.updateCamera(cameraId, cameraData);
      if (_isDisposed) return;

      final idx = _cameras.indexWhere((c) => c.id == cameraId);
      if (idx != -1) {
        _cameras[idx] = updated;
      }

      await validateCameraQuota();

      if (!_isDisposed) notifyListeners();
    } catch (e) {
      throw Exception('Failed to update camera: $e');
    }
  }

  Future<void> deleteCamera(CameraEntry camera) async {
    if (_isDisposed) return;

    _cameras.removeWhere((c) => c.id == camera.id);
    notifyListeners();

    _pendingDeletedEntries[camera.id] = camera;
    _pendingDeleteTimers[camera.id]?.cancel();
    _pendingDeleteTimers[camera.id] = Timer(const Duration(seconds: 5), () {
      if (_isDisposed) return;
      _pendingDeleteTimers.remove(camera.id);
      _pendingDeletedEntries.remove(camera.id);
    });

    try {
      await _cameraService.deleteCamera(camera.id);
    } catch (e) {
      if (!_isDisposed) {
        _cameras.add(camera);
        notifyListeners();
      }
      throw Exception('Failed to delete camera: $e');
    }
  }

  void undoDelete(String cameraId) {
    if (_isDisposed) return;

    final timer = _pendingDeleteTimers[cameraId];
    final camera = _pendingDeletedEntries[cameraId];

    if (timer != null && camera != null) {
      timer.cancel();
      _pendingDeleteTimers.remove(cameraId);
      _pendingDeletedEntries.remove(cameraId);
      _cameras.add(camera);
      notifyListeners();
    }
  }

  Future<void> refreshThumbnails() async {
    if (_cameras.isEmpty || _isDisposed) return;

    _refreshing = true;
    notifyListeners();

    try {
      await _cameraService.refreshThumbnails(
        _cameras.map((c) => c.id).toList(),
      );
      if (!_isDisposed) {
        _lastRefreshed = DateTime.now();
      }
    } catch (e) {
      debugPrint('Thumbnail refresh failed: $e');
    } finally {
      if (!_isDisposed) {
        _refreshing = false;
        notifyListeners();
      }
    }
  }

  void updateSearch(String value) {
    if (_isDisposed) return;

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_isDisposed) return;
      _search = value;
      notifyListeners();
    });
  }

  void toggleView() {
    if (_isDisposed) return;
    _grid = !_grid;
    notifyListeners();
  }

  void toggleSort() {
    if (_isDisposed) return;
    _sortAsc = !_sortAsc;
    notifyListeners();
  }

  void refreshCameraThumb(CameraEntry camera) {
    if (_isDisposed) return;

    final index = _cameras.indexWhere((c) => c.id == camera.id);
    if (index != -1) {
      final updatedCamera = CameraEntry(
        id: camera.id,
        name: camera.name,
        url: camera.url,
        thumb: _cameraService.cacheBustThumb(camera.thumb),
        isOnline: camera.isOnline,
      );
      _cameras[index] = updatedCamera;
      notifyListeners();
    }
  }

  Future<void> validateCameraQuota() async {
    if (_isDisposed) return;

    try {
      _quotaValidation = await _quotaService.canAddCamera(_cameras.length);
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error validating camera quota: $e');
      if (!_isDisposed) {
        _quotaValidation = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebounceTimer?.cancel();
    for (final timer in _pendingDeleteTimers.values) {
      timer.cancel();
    }
    _pendingDeleteTimers.clear();
    _pendingDeletedEntries.clear();
    super.dispose();
  }
}
