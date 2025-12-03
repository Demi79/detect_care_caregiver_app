import 'dart:async';

// ignore_for_file: unused_field

import 'package:detect_care_caregiver_app/core/network/api_client.dart';
import 'package:detect_care_caregiver_app/features/auth/data/auth_storage.dart';
import 'package:detect_care_caregiver_app/features/auth/models/login_result.dart';
import 'package:detect_care_caregiver_app/features/auth/models/user.dart';
import 'package:detect_care_caregiver_app/features/auth/repositories/auth_repository.dart';
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
      print("⚠️ Save FCM token failed: $e");
    }

    final bool hasAssigned =
        user!.isAssigned || await _hasAcceptedAssignmentFor(user!.id);

    print(
      '[Auth] caregiverLogin -> hasAssigned=$hasAssigned, isAssigned=${user!.isAssigned}',
    );

    if (hasAssigned || user!.isAssigned) {
      _set(AuthStatus.authenticated);
    } else {
      _set(AuthStatus.assignVerified);
    }
    return loginResult;
  }

  Future<void> sendOtp(String phone) async {
    if (kDebugMode) {
      print('[Auth] Sending OTP to phone: $phone');
    }
    final result = await repo.sendOtp(phone);
    lastOtpRequestMessage = result.message;
    lastOtpCallId = result.callId;
    _pendingPhone = phone;
    if (kDebugMode) {
      print(
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
        print('[Auth] OTP verified -> authenticated as ${user!.fullName}');
      }
      final bool hasAssigned =
          user!.isAssigned || await _hasAcceptedAssignmentFor(user!.id);

      print(
        '[Auth] verifyOtp -> hasAssigned=$hasAssigned, isAssigned=${user!.isAssigned}',
      );

      if (hasAssigned || user!.isAssigned) {
        _set(AuthStatus.authenticated);
      } else {
        _set(AuthStatus.assignVerified);
      }
    } catch (err) {
      if (kDebugMode) print('[Auth] verifyOtp failed: $err');
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
      print('[Auth] status: ${status.name} -> ${s.name}');
      print('[Auth] currentUser: ${user?.id}, supabaseUser: ${supaUser?.id}');
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

        print(
          '[Auth] _loadFromPrefs -> hasAssigned=$hasAssigned, isAssigned=${user!.isAssigned}',
        );

        if (hasAssigned || user!.isAssigned) {
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

        print(
          '[Auth] reloadUser -> hasAssigned=$hasAssigned, prevAssigned=$prevAssigned, isAssigned=${user!.isAssigned}',
        );

        if (prevAssigned && !hasAssigned) {
          try {
            onAssignmentLost?.call();
          } catch (e) {
            print('[Auth] onAssignmentLost handler failed: $e');
          }
          _set(AuthStatus.assignVerified);
        }

        _wasAssigned = hasAssigned;

        if (hasAssigned || user!.isAssigned) {
          _set(AuthStatus.authenticated);
        } else {
          _set(AuthStatus.assignVerified);
        }
      }
    } catch (e) {
      print("[Auth] reloadUser error: $e");
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

      print(
        '[Auth] caregiverVerifyOtp -> hasAssigned=$hasAssigned, isAssigned=${user!.isAssigned}',
      );

      if (hasAssigned || user!.isAssigned) {
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
      bool recordContainsUid(dynamic record, String uid) {
        try {
          if (record == null) return false;
          if (record is String) return record == uid;
          if (record is Map) {
            final candidates = [
              'caregiver_id',
              'caregiverId',
              'caregiver',
              'caregiver_uuid',
              'user_id',
              'userId',
              'owner_id',
              'customer_id',
            ];
            for (final k in candidates) {
              if (record.containsKey(k) && record[k] != null) {
                if (record[k].toString() == uid) return true;
              }
            }
            for (final v in record.values) {
              if (v == null) continue;
              if (v is String && v == uid) return true;
              if (v is Map && recordContainsUid(v, uid)) return true;
              if (v is List) {
                for (final e in v) {
                  if (e == null) continue;
                  if (e is String && e == uid) return true;
                  if (e is Map && recordContainsUid(e, uid)) return true;
                }
              }
            }
          }
          return false;
        } catch (_) {
          return false;
        }
      }

      final name = 'caregiver_invitations_$uid';
      _invitationChannel =
          supa
              .channel(name)
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'caregiver_invitations',
                callback: (payload) async {
                  try {
                    final Map row = payload.newRecord;
                    if (recordContainsUid(row, uid)) {
                      print('[Auth] invitation insert for me: $row');
                      await reloadUser();
                    } else {
                      print('[Auth] invitation insert (not mine): $row');
                    }
                  } catch (e) {
                    print('[Auth] invitation insert handler error: $e');
                  }
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'caregiver_invitations',
                callback: (payload) async {
                  try {
                    final Map row = payload.newRecord;
                    if (recordContainsUid(row, uid)) {
                      print('[Auth] invitation update for me: $row');
                      await reloadUser();
                    } else {
                      print('[Auth] invitation update (not mine): $row');
                    }
                  } catch (e) {
                    print('[Auth] invitation update handler error: $e');
                  }
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.delete,
                schema: 'public',
                table: 'caregiver_invitations',
                callback: (payload) async {
                  try {
                    final Map row = payload.oldRecord;
                    if (recordContainsUid(row, uid)) {
                      print('[Auth] caregiver_invitations delete for me: $row');
                      await reloadUser();
                    }
                  } catch (e) {
                    print(
                      '[Auth] caregiver_invitations delete handler error: $e',
                    );
                  }
                },
              )
            // .onPostgresChanges(
            //   event: PostgresChangeEvent.update,
            //   schema: 'public',
            //   table: 'caregiver_invitations',
            //   callback: (payload) async {
            //     try {
            //       final Map row = payload.newRecord;
            //       if (recordContainsUid(row, uid)) {
            //         final status = row['status']?.toString()?.toLowerCase();
            //         if (status == 'cancelled' ||
            //             status == 'inactive' ||
            //             status == 'revoked') {
            //           print(
            //             '[Auth] caregiver_invitations status=$status for me, reloading...',
            //           );
            //           await reloadUser();
            //         }
            //       }
            //     } catch (e) {
            //       print(
            //         '[Auth] caregiver_invitations update handler error: $e',
            //       );
            //     }
            //   },
            // )
            // .onPostgresChanges(
            //   event: PostgresChangeEvent.truncate,
            //   schema: 'public',
            //   table: 'caregiver_invitations',
            //   callback: (_) async {
            //     await reloadUser();
            //   },
            // )
            ..subscribe((status, error) {
              print('[Auth] invitation channel status: $status');
              if (error != null) {
                print('[Auth] Supabase invitation channel error: $error');
                Future.delayed(const Duration(seconds: 5), () {
                  if (_invitationChannel != null) {
                    _invitationChannel!.subscribe();
                  }
                });
                return;
              }
              if (kDebugMode) {
                print('[Auth] invitation channel status: $status');
              }
            });
    } catch (e) {
      print('[Auth] _ensureInvitationSubscription failed: $e');
    }
  }

  void _disposeInvitationSubscription() {
    try {
      if (_invitationChannel != null) {
        if (kDebugMode) print('[Auth] disposing invitation channel');
        _invitationChannel!.unsubscribe();
        _invitationChannel = null;
      }
    } catch (e) {
      print('[Auth] _disposeInvitationSubscription error: $e');
    }
  }

  Future<bool> _hasAcceptedAssignmentFor(String userId) async {
    try {
      final ds = AssignmentsRemoteDataSource();
      final list = await ds.listPending(status: 'accepted');
      return list.any((a) => a.caregiverId == userId && a.isActive);
    } catch (e) {
      if (kDebugMode) print('[Auth] _hasAcceptedAssignmentFor error: $e');
      return false;
    }
  }

  Future<String?> getUserIdFromPrefs() => AuthStorage.getUserId();
}
