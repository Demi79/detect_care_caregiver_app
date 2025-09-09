import 'package:detect_care_caregiver_app/features/me/data/me_preferences_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/patient/data/medical_info_remote_data_source.dart';

class OnboardingService {
  final MePreferencesRemoteDataSource mePrefs;
  final MedicalInfoRemoteDataSource medical;
  OnboardingService({
    MePreferencesRemoteDataSource? mePrefs,
    MedicalInfoRemoteDataSource? medical,
  }) : mePrefs = mePrefs ?? MePreferencesRemoteDataSource(),
       medical = medical ?? MedicalInfoRemoteDataSource();

  Future<void> seedDefaultsForUser(String userId) async {
    // Preferences defaults
    await mePrefs.setAppearance(theme: 'light', font: 'system');
    await mePrefs.setNotifications(
      type: 'all',
      mobile: true,
      communicationEmails: false,
      socialEmails: false,
      marketingEmails: false,
      securityEmails: true,
    );
    await mePrefs.setDisplay(items: <String>[]);

    // Create medical-info shell if none exists (empty patient/record)
    try {
      await medical.upsertMedicalInfo(userId);
    } catch (_) {
      // ignore; backend may accept empty upsert or already exists
    }
  }
}
