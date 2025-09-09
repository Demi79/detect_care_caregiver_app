class FcmEndpoints {
  final String base;
  FcmEndpoints(this.base);

  String get postTokenPath => '/fcm/token';
  String get postMessagePath => '/fcm/push/message';

  Uri get postTokenUri => Uri.parse('$base/fcm/token');
  Uri get postMessageUri => Uri.parse('$base/fcm/push/message');
}
