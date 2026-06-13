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

/// 작성 [createdAt] 기준 [limitHours]시간 뒤 만료까지 남은 시간을 한국어로.
/// 텍스트 카드의 노출 제한(기본 48시간)을 "남은 시간"으로 보여줄 때 사용.
/// - 이미 만료/계산 불가 → "" (호출부에서 뱃지 숨김)
/// - `< 1시간` → "곧 사라짐"
/// - `< 24시간` → "N시간 남음"
/// - 그 외 → "N일 남음"
String remainingTime(DateTime createdAt,
    {int limitHours = 48, DateTime? reference}) {
  final now = reference ?? DateTime.now();
  final left = createdAt.add(Duration(hours: limitHours)).difference(now);
  if (left.isNegative) return '';
  if (left.inHours < 1) return '곧 사라짐';
  if (left.inHours < 24) return '${left.inHours}시간 남음';
  return '${left.inDays}일 남음';
}

/// ISO-8601 문자열 버전. 파싱 실패/빈 값이면 "" 반환(뱃지 숨김).
String remainingTimeFromString(String iso,
    {int limitHours = 48, DateTime? reference}) {
  if (iso.isEmpty) return '';
  try {
    return remainingTime(DateTime.parse(iso),
        limitHours: limitHours, reference: reference);
  } catch (_) {
    return '';
  }
}
