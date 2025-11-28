import 'package:detect_care_caregiver_app/features/profile/model/user_profile.dart';
import 'package:detect_care_caregiver_app/features/profile/data/user_remote_data_source.dart';

class UsersRepository {
  final UsersRemoteDataSource remote;

  UsersRepository(this.remote);

  Future<UserProfile> fetchUser(String userId) async {
    try {
      return await remote.getUser(userId);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateUser(String userId, UserProfile user) async {
    try {
      return await remote.updateUser(userId, user.toUpdatePayload());
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateUserWithBody(
    String userId,
    Map<String, dynamic> body,
  ) async {
    try {
      return await remote.updateUser(userId, body);
    } catch (e) {
      rethrow;
    }
  }
}
