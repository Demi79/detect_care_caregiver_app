class OtpRequestResult {
  final int? r;
  final String message;
  final String? callId;
  const OtpRequestResult({this.r, required this.message, this.callId});

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) =>
      OtpRequestResult(
        r: json['r'] is int ? json['r'] as int : int.tryParse('${json['r']}'),
        message: (json['message'] ?? '').toString(),
        callId: json['call_id']?.toString(),
      );
}
