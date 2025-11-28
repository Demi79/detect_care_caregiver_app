import '../models/plan.dart';

/// Fallback plans used when API is unavailable or for testing
class PlanConstants {
  static final List<Plan> fallbackPlans = [
    Plan(
      code: 'basic',
      name: 'Gói Cơ bản',
      price: 0,
      cameraQuota: 1,
      retentionDays: 7,
      caregiverSeats: 1,
      sites: 1,
      majorUpdatesMonths: 12,
      createdAt: DateTime.now(),
      storageSize: '5GB',
      isRecommended: false,
    ),
    Plan(
      code: 'pro',
      name: 'Gói Nâng cao',
      price: 99000,
      cameraQuota: 4,
      retentionDays: 30,
      caregiverSeats: 3,
      sites: 2,
      majorUpdatesMonths: 6,
      createdAt: DateTime.now(),
      storageSize: '50GB',
      isRecommended: true,
    ),
    Plan(
      code: 'premium',
      name: 'Gói Cao cấp',
      price: 199000,
      cameraQuota: 8,
      retentionDays: 90,
      caregiverSeats: 6,
      sites: 4,
      majorUpdatesMonths: 3,
      createdAt: DateTime.now(),
      storageSize: '200GB',
      isRecommended: false,
    ),
  ];
}
