import 'package:detect_care_caregiver_app/features/profile/model/user_profile.dart';
import 'package:detect_care_caregiver_app/features/profile/repositories/user_repositories.dart';

class UsersService {
  final UsersRepository repo;

  UsersService(this.repo);

  Future<UserProfile> getUserInfo(String userId) {
    return repo.fetchUser(userId);
  }

  Future<bool> updateUserInfo(String userId, UserProfile user) {
    return repo.updateUser(userId, user);
  }

  Future<bool> updateUserFields(String userId, Map<String, dynamic> body) {
    return repo.updateUserWithBody(userId, body);
  }
}
