class UserProfile {
  final String userId;
  final String username;
  final String email;
  final String fullName;
  final String phoneNumber;

  final String type;
  final bool isActive;
  final String joined;
  final String planName;
  final String planCode;
  final int cameraQuota;
  final int cameraQuotaUsed;
  final int alertsTotal;
  final int alertsUnresolved;
  final int paymentsTotal;
  final int paymentsPending;
  final String subscriptionStatus;

  const UserProfile({
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.type,
    required this.isActive,
    required this.joined,
    required this.planName,
    required this.planCode,
    required this.cameraQuota,
    required this.cameraQuotaUsed,
    required this.alertsTotal,
    required this.alertsUnresolved,
    required this.paymentsTotal,
    required this.paymentsPending,
    required this.subscriptionStatus,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    userId: j['user_id'],
    username: j['username'] ?? "",
    email: j['email'] ?? "",
    fullName: j['full_name'] ?? "",
    phoneNumber: j['phone_number'] ?? "",
    type: j['role'] ?? j['type'] ?? "",
    isActive: j['is_active'] ?? true,
    joined: j['joined'] ?? j['created_at'] ?? "",
    planName: j['plan_name'] ?? "",
    planCode: j['plan_code'] ?? "",
    cameraQuota: j['camera_quota'] ?? 0,
    cameraQuotaUsed: j['camera_quota_used'] ?? 0,
    alertsTotal: j['alerts_total'] ?? 0,
    alertsUnresolved: j['alerts_unresolved'] ?? 0,
    paymentsTotal: j['payments_total'] ?? 0,
    paymentsPending: j['payments_pending'] ?? 0,
    subscriptionStatus: j['subscription_status'] ?? "",
  );

  Map<String, dynamic> toUpdatePayload() => {
    "username": username,
    "email": email,
    "phone_number": phoneNumber,
    "full_name": fullName,
  };

  UserProfile copyWith({
    String? username,
    String? email,
    String? fullName,
    String? phoneNumber,
  }) {
    return UserProfile(
      userId: userId,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      type: type,
      isActive: isActive,
      joined: joined,
      planName: planName,
      planCode: planCode,
      cameraQuota: cameraQuota,
      cameraQuotaUsed: cameraQuotaUsed,
      alertsTotal: alertsTotal,
      alertsUnresolved: alertsUnresolved,
      paymentsTotal: paymentsTotal,
      paymentsPending: paymentsPending,
      subscriptionStatus: subscriptionStatus,
    );
  }
}
