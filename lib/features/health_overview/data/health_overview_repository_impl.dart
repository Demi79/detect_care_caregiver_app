import 'package:detect_care_caregiver_app/features/health_overview/repositories/health_overview_repository.dart';

import '../models/health_overview_models.dart';
import 'health_overview_remote_data_source.dart';

class HealthOverviewRepositoryImpl implements HealthOverviewRepository {
  final HealthOverviewRemoteDataSource remote;

  HealthOverviewRepositoryImpl(this.remote);

  @override
  Future<HealthOverviewData> getOverview({
    String? customerId,
    String? startDate,
    String? endDate,
  }) {
    return remote.fetchOverview(
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
