import 'package:detect_care_caregiver_app/features/health_overview/models/health_overview_models.dart';

abstract class HealthOverviewRepository {
  Future<HealthOverviewData> getOverview({
    String? customerId,
    String? startDate,
    String? endDate,
  });
}
