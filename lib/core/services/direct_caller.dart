import 'package:flutter/services.dart';

class DirectCaller {
  static const _channel = MethodChannel('detect_care_app/direct_call');

  static Future<bool> call(String phone) async {
    try {
      final ok = await _channel.invokeMethod('makeDirectCall', {
        'number': phone,
      });
      return ok == true;
    } catch (e) {
      print('Error direct call: $e');
      return false;
    }
  }
}
