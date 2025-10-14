import 'dart:async';
import 'dart:convert';

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/models/login_result.dart';
import 'package:detect_care_caregiver_app/features/auth/models/user.dart';
import 'package:detect_care_caregiver_app/features/auth/repositories/auth_repository.dart';
import 'package:detect_care_caregiver_app/services/push_service.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

enum AuthStatus {
  loading,
  unauthenticated,
  otpSent,
  assignVerified,
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  late final ApiClient _api;
  final AuthRepository repo;

  RealtimeChannel? _invitationChannel;

  Future<void> Function()? onAssignmentLost;

  bool _wasAssigned = false;

  AuthProvider(this.repo) {
    _api = ApiClient(tokenProvider: () => AuthStorage.getAccessToken());
    _loadFromPrefs();
  }
  // Future<void> saveFcmToken(String userId) async {
  //   final token = await PushService.instance.getFcmToken();
  //   if (token == null) return;

  //   final payloads = [
  //     {'userId': userId, 'token': token, 'type': 'device'},
  //     {'userId': userId, 'token': token, 'type': 'caregiver'},
  //   ];

  //   // Gửi cả 2 request đồng thời
  //   final results = await Future.wait(payloads.map((body) {
  //     return _api.post(
  //       '/fcm/token',
  //       body: json.encode(body),
  //     );
  //   }));

  //   for (var i = 0; i < results.length; i++) {
  //     final res = results[i];
  //     final type = payloads[i]['type'];
  //     if (res.statusCode != 200) {
  //       throw Exception(
  //         'Failed to save FCM token ($type): ${res.statusCode} ${res.body}',
  //       );
  //     } else {
  //       debugPrint('✅ Saved FCM token for type=$type');
  //     }
  //   }
  // }

  Future<void> logout() async {
    await AuthStorage.clear();
    user = null;
    _cachedUserId = null;
    _disposeInvitationSubscription();
    _set(AuthStatus.unauthenticated);
  }

  Future<LoginResult> caregiverLoginWithPassword(
    String email,
    String password,
  ) async {
    final loginResult = await repo.remote.caregiverLoginWithPassword(
      email,
      password,
    );

    await AuthStorage.saveAuthResult(
      accessToken: loginResult.accessToken,
      userJson: loginResult.userServerJson,
    );
    user = loginResult.user;
    _cachedUserId = user!.id;

    try {
      await repo.remote.saveFcmToken(loginResult.user.id);
    } catch (e) {
      debugPrint("⚠️ Save FCM token failed: $e");
    }

    final bool hasAssigned =
        user!.isAssigned || await _hasAcceptedAssignmentFor(user!.id);
    if (hasAssigned) {
      _set(AuthStatus.authenticated);
    } else {
      _set(AuthStatus.assignVerified);
    }
    return loginResult;
  }

  Future<void> sendOtp(String phone) async {
    if (kDebugMode) {
      debugPrint('[Auth] Sending OTP to phone: $phone');
    }
    final result = await repo.sendOtp(phone);
    lastOtpRequestMessage = result.message;
    lastOtpCallId = result.callId;
    _pendingPhone = phone;
    if (kDebugMode) {
      debugPrint(
        '[Auth] OTP sent successfully. Message: ${result.message}, CallId: ${result.callId}',
      );
    }
    _set(AuthStatus.otpSent);
  }

  Future<void> verifyOtp(String phone, String code, {String? callId}) async {
    _set(AuthStatus.loading);
    try {
      final res = await repo
          .verifyOtp(phone, code)
          .timeout(const Duration(seconds: 12));

      await AuthStorage.saveAuthResult(
        accessToken: res.accessToken,
        userJson: res.userServerJson,
      );

      user = res.user;
      _cachedUserId = user!.id;
      if (kDebugMode) {
        debugPrint('[Auth] OTP verified -> authenticated as ${user!.fullName}');
      }
      final bool hasAssigned =
          user!.isAssigned || await _hasAcceptedAssignmentFor(user!.id);
      if (hasAssigned) {
        _set(AuthStatus.authenticated);
      } else {
        _set(AuthStatus.assignVerified);
      }
    } catch (err) {
      if (kDebugMode) debugPrint('[Auth] verifyOtp failed: $err');
      _set(AuthStatus.unauthenticated);
      rethrow;
    }
  }

  AuthStatus status = AuthStatus.loading;
  User? user;
  String? _pendingPhone;
  String? get pendingPhone => _pendingPhone;

  String? lastOtpRequestMessage;
  String? lastOtpCallId;

  String? _cachedUserId;

  String? get currentUserId => user?.id ?? _cachedUserId;

  void _set(AuthStatus s) {
    if (kDebugMode) {
      final supaUser = Supabase.instance.client.auth.currentUser;
      debugPrint('[Auth] status: ${status.name} -> ${s.name}');
      debugPrint(
        '[Auth] currentUser: ${user?.id}, supabaseUser: ${supaUser?.id}',
      );
    }
    status = s;
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    _set(AuthStatus.loading);
    final token = await AuthStorage.getAccessToken();
    if (token == null) {
      _set(AuthStatus.unauthenticated);
      return;
    }
    final userJson = await AuthStorage.getUserJson();
    if (userJson != null) {
      user = User.fromJson(userJson);
      _cachedUserId = user?.id;
      _ensureInvitationSubscription();
      if (user != null) {
        final bool hasAssigned =
            user!.isAssigned || await _hasAcceptedAssignmentFor(user!.id);
        if (hasAssigned) {
          _set(AuthStatus.authenticated);
        } else {
          _set(AuthStatus.assignVerified);
        }
      } else {
        _set(AuthStatus.unauthenticated);
      }
    } else {
      _cachedUserId = await AuthStorage.getUserId();
      _set(AuthStatus.unauthenticated);
    }
  }

  void resetToUnauthenticated() {
    _set(AuthStatus.unauthenticated);
  }

  Future<void> reloadUser() async {
    try {
      final newUser = await repo.me();
      if (newUser != null) {
        final prevAssigned = user?.isAssigned ?? _wasAssigned;
        user = newUser;
        _cachedUserId = user?.id;
        _ensureInvitationSubscription();
        final bool hasAssigned =
            user!.isAssigned || await _hasAcceptedAssignmentFor(user!.id);

        if (prevAssigned && !hasAssigned) {
          try {
            onAssignmentLost?.call();
          } catch (e) {
            debugPrint('[Auth] onAssignmentLost handler failed: $e');
          }
        }

        _wasAssigned = hasAssigned;

        if (hasAssigned) {
          _set(AuthStatus.authenticated);
        } else {
          _set(AuthStatus.assignVerified);
        }
      }
    } catch (e) {
      debugPrint("[Auth] reloadUser error: $e");
    }
  }

  Future<void> caregiverVerifyOtp(String phone, String code) async {
    _set(AuthStatus.loading);
    try {
      final res = await repo.remote.caregiverLogin(phone, code);

      await AuthStorage.saveAuthResult(
        accessToken: res.accessToken,
        userJson: res.userServerJson,
      );

      user = res.user;
      _cachedUserId = user!.id;

      final bool hasAssigned =
          user!.isAssigned || await _hasAcceptedAssignmentFor(user!.id);
      if (hasAssigned) {
        _set(AuthStatus.authenticated);
      } else {
        _set(AuthStatus.assignVerified);
      }
    } catch (err) {
      _set(AuthStatus.unauthenticated);
      rethrow;
    }
  }

  void _ensureInvitationSubscription() {
    try {
      final uid = _cachedUserId ?? user?.id;
      if (uid == null || uid.isEmpty) {
        _disposeInvitationSubscription();
        return;
      }

      _disposeInvitationSubscription();

      final supa = Supabase.instance.client;
      final name = 'caregiver_invitations_$uid';
      _invitationChannel =
          supa
              .channel(name)
              // Insert
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'caregiver_invitations',
                callback: (payload) async {
                  try {
                    final Map row = payload.newRecord;
                    final cid = row['caregiver_id']?.toString();
                    if (cid == uid) {
                      if (kDebugMode)
                        debugPrint('[Auth] invitation insert for me: $row');
                      await reloadUser();
                    }
                  } catch (e) {
                    debugPrint('[Auth] invitation insert handler error: $e');
                  }
                },
              )
              // Update
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'caregiver_invitations',
                callback: (payload) async {
                  try {
                    final Map row = payload.newRecord;
                    final cid = row['caregiver_id']?.toString();
                    if (cid == uid) {
                      if (kDebugMode)
                        debugPrint('[Auth] invitation update for me: $row');
                      await reloadUser();
                    }
                  } catch (e) {
                    debugPrint('[Auth] invitation update handler error: $e');
                  }
                },
              )
              // Delete
              .onPostgresChanges(
                event: PostgresChangeEvent.delete,
                schema: 'public',
                table: 'caregiver_invitations',
                callback: (payload) async {
                  try {
                    final Map row = payload.oldRecord;
                    final cid = row['caregiver_id']?.toString();
                    if (cid == uid) {
                      if (kDebugMode)
                        debugPrint('[Auth] invitation delete for me: $row');
                      await reloadUser();
                    }
                  } catch (e) {
                    debugPrint('[Auth] invitation delete handler error: $e');
                  }
                },
              )
            ..subscribe((status, error) {
              if (error != null) {
                debugPrint('[Auth] Supabase invitation channel error: $error');
                Future.delayed(const Duration(seconds: 5), () {
                  if (_invitationChannel != null)
                    _invitationChannel!.subscribe();
                });
                return;
              }
              if (kDebugMode)
                debugPrint('[Auth] invitation channel status: $status');
            });
    } catch (e) {
      debugPrint('[Auth] _ensureInvitationSubscription failed: $e');
    }
  }

  void _disposeInvitationSubscription() {
    try {
      if (_invitationChannel != null) {
        if (kDebugMode) debugPrint('[Auth] disposing invitation channel');
        _invitationChannel!.unsubscribe();
        _invitationChannel = null;
      }
    } catch (e) {
      debugPrint('[Auth] _disposeInvitationSubscription error: $e');
    }
  }

  Future<bool> _hasAcceptedAssignmentFor(String userId) async {
    try {
      final ds = AssignmentsRemoteDataSource();
      final list = await ds.listPending(status: 'accepted');
      return list.any((a) => a.caregiverId == userId && a.isActive);
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] _hasAcceptedAssignmentFor error: $e');
      return false;
    }
  }

  Future<String?> getUserIdFromPrefs() => AuthStorage.getUserId();
}
