/// Returns a Korean relative-time string for [when], compared against [reference]
/// (defaults to `DateTime.now()`).
///
/// Rules:
/// - `< 1분` → "방금 전"
/// - `< 60분` → "N분 전"
/// - `< 24시간` → "N시간 전"
/// - `< 7일` → "N일 전" (Duration.inDays 기준 — 총 시간(hour) 단위, 달력 자정 경계가 아님)
/// - 그 외 → "YYYY-MM-DD"
///
/// Assumes [when] is in the past relative to [reference].
/// Future timestamps (clock skew) are not defined behaviour.
String relativeTime(DateTime when, {DateTime? reference}) {
  final now = reference ?? DateTime.now();
  final diff = now.difference(when);

  if (diff.inSeconds < 60) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';

  final y = when.year.toString().padLeft(4, '0');
  final m = when.month.toString().padLeft(2, '0');
  final d = when.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses an ISO-8601 string and returns [relativeTime].
/// Returns "방금 전" if parsing fails or input is empty.
String relativeTimeFromString(String iso, {DateTime? reference}) {
  if (iso.isEmpty) return '방금 전';
  try {
    return relativeTime(DateTime.parse(iso), reference: reference);
  } catch (_) {
    return '방금 전';
  }
}
