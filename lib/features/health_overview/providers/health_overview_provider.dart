import 'package:detect_care_caregiver_app/features/health_overview/models/health_overview_models.dart';
import 'package:detect_care_caregiver_app/features/health_overview/repositories/health_overview_repository.dart';
import 'package:flutter/material.dart';

class HealthOverviewProvider extends ChangeNotifier {
  final HealthOverviewRepository repo;
  HealthOverviewProvider(this.repo);

  HealthOverviewData? _data;
  bool _isLoading = false;
  String? _error;

  HealthOverviewData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load({
    String? customerId,
    String? startDate,
    String? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await repo.getOverview(
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _data = null;
    _error = null;
    notifyListeners();
  }
}
