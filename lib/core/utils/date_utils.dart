import 'package:intl/intl.dart';

class AppDateUtils {
  static String formatDobForDisplay(String isoOrRaw) {
    if (isoOrRaw.isEmpty) return '';

    try {
      final dt = DateTime.parse(isoOrRaw);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      // not full ISO
    }

    final patterns = [
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('dd-MM-yyyy'),
    ];
    for (final pattern in patterns) {
      try {
        final dt = pattern.parseStrict(isoOrRaw);
        return DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {
        // ignore
      }
    }

    return isoOrRaw;
  }
}
