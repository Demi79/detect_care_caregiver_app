import 'package:detect_care_caregiver_app/features/auth/data/auth_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/auth/models/otp_request_result.dart';
import 'package:detect_care_caregiver_app/features/auth/models/user.dart';
import 'package:detect_care_caregiver_app/features/auth/models/login_result.dart';

class AuthRepository {
  final AuthRemoteDataSource remote;
  AuthRepository(this.remote);

  Future<User> register(String phone, String password) =>
      remote.createUser(phone, password);

  Future<OtpRequestResult> sendOtp(String phone) => remote.sendOtp(phone);

  Future<LoginResult> verifyOtp(String phone, String code) =>
      remote.verifyOtp(phone, code);

  Future<OtpRequestResult> requestOtp(String phone) => remote.sendOtp(phone);

  Future<User?> me() async {
    try {
      return await remote.me();
    } catch (_) {
      return null;
    }
  }
}
