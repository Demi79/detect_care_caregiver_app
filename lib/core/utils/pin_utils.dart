import 'dart:math';

class PinUtils {
  static String generatePin({int length = 6}) {
    final rnd = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(rnd.nextInt(10));
    }
    return buffer.toString();
  }
}
