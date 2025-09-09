import 'package:detect_care_caregiver_app/core/config/app_config.dart';
import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/fcm/data/fcm_endpoints.dart';
import 'package:detect_care_caregiver_app/features/fcm/data/fcm_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/fcm/services/fcm_registration.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';

class FcmQuickSendController {
  final FcmRemoteDataSource _fcmDs;
  final FcmRegistration _fcmReg;
  final AssignmentsRemoteDataSource _assignDs;

  FcmQuickSendController._(this._fcmDs, this._fcmReg, this._assignDs);

  factory FcmQuickSendController.create() {
    final fcmDs = FcmRemoteDataSource(
      api: ApiClient(tokenProvider: AuthStorage.getAccessToken),
      endpoints: FcmEndpoints(AppConfig.apiBaseUrl),
    );
    return FcmQuickSendController._(
      fcmDs,
      FcmRegistration(fcmDs),
      AssignmentsRemoteDataSource(),
    );
  }

  Future<List<String>> _getAcceptedActiveCustomerIds() async {
    final list = await _assignDs.listPending();
    return list
        .where((a) => a.status.toLowerCase() == 'accepted' && a.isActive)
        .map((a) => a.customerId)
        .toSet()
        .toList();
  }

  Future<Map<String, dynamic>> sendMessage({
    required String caregiverId,
    required String message,
    String? toCustomerId,
  }) async {
    if (message.trim().isEmpty) {
      throw ArgumentError('Message không được để trống');
    }

    if (message.length > 512) {
      throw ArgumentError('Message không được dài quá 512 ký tự');
    }

    await _fcmReg.registerForUser(caregiverId, type: 'device');
    await _fcmReg.getCurrentTokenSafely();

    final List<String> toUserIds;
    if (toCustomerId == null || toCustomerId.isEmpty) {
      toUserIds = await _getAcceptedActiveCustomerIds();
    } else {
      toUserIds = [toCustomerId];
    }

    if (toUserIds.isEmpty) {
      return {'successCount': 0, 'failureCount': 0, 'info': 'no_recipients'};
    }

    if (toUserIds.length > 50) {
      throw ArgumentError('Không thể gửi cho quá 50 người nhận');
    }

    return await _fcmDs.pushMessage(
      toUserIds: toUserIds,
      direction: 'caregiver_to_customer',
      category: 'report',
      message: message,
      fromUserId: caregiverId,
    );
  }

  void dispose() {
    _fcmReg.dispose();
  }
}
