import 'package:detect_care_caregiver_app/features/fcm/data/fcm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';

class FcmMessagingService {
  final FcmRemoteDataSource pushDs;
  final AssignmentsRemoteDataSource assignmentsDs;

  FcmMessagingService({required this.pushDs, required this.assignmentsDs});

  Future<List<String>> listAcceptedCustomerIdsForMe() async {
    final list = await assignmentsDs.listPending();
    return list
        .where((a) => a.status.toLowerCase() == 'accepted' && a.isActive)
        .map((a) => a.customerId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<Map<String, dynamic>> sendFromCaregiver({
    required String caregiverId,
    required String message,
    String category = 'report',
    List<String>? toCustomerIds,
    String? deeplink,
  }) async {
    final targets = (toCustomerIds == null || toCustomerIds.isEmpty)
        ? await listAcceptedCustomerIdsForMe()
        : toCustomerIds;

    return pushDs.pushMessage(
      toUserIds: targets,
      direction: 'caregiver_to_customer',
      category: category,
      message: message,
      fromUserId: caregiverId,
      deeplink: deeplink,
    );
  }

  Future<Map<String, dynamic>> sendFromCustomer({
    required String customerId,
    required List<String> toCaregiverIds,
    required String message,
    String category = 'help',
    String? deeplink,
  }) {
    return pushDs.pushMessage(
      toUserIds: toCaregiverIds,
      direction: 'customer_to_caregiver',
      category: category,
      message: message,
      fromUserId: customerId,
      deeplink: deeplink,
    );
  }
}
