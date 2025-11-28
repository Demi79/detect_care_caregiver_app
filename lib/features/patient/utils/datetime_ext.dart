extension DateDisplay on String {
  String toDateTimeDisplay() {
    try {
      final dt = DateTime.parse(this).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} – ${dt.day}/${dt.month}";
    } catch (e) {
      return this;
    }
  }
}
