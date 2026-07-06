/// Doc ID for [locationHistory]: ISO local time truncated to the minute.
String locationHistoryDocId(DateTime capturedAt) {
  final t = DateTime(
    capturedAt.year,
    capturedAt.month,
    capturedAt.day,
    capturedAt.hour,
    capturedAt.minute,
  );
  final y = t.year.toString().padLeft(4, '0');
  final m = t.month.toString().padLeft(2, '0');
  final d = t.day.toString().padLeft(2, '0');
  final h = t.hour.toString().padLeft(2, '0');
  final min = t.minute.toString().padLeft(2, '0');
  return '$y-$m-${d}T$h:$min:00';
}
