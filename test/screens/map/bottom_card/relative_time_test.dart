import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';

void main() {
  group('relativeTime', () {
    final now = DateTime(2026, 5, 13, 12, 0, 0);

    test('returns "방금 전" for < 1 minute', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 30)), reference: now), '방금 전');
      expect(relativeTime(now.subtract(const Duration(seconds: 59)), reference: now), '방금 전');
    });

    test('returns "N분 전" for 1 minute to 59 minutes', () {
      expect(relativeTime(now.subtract(const Duration(minutes: 1)), reference: now), '1분 전');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), reference: now), '5분 전');
      expect(relativeTime(now.subtract(const Duration(minutes: 59)), reference: now), '59분 전');
    });

    test('returns "N시간 전" for 1 hour to 23 hours', () {
      expect(relativeTime(now.subtract(const Duration(hours: 1)), reference: now), '1시간 전');
      expect(relativeTime(now.subtract(const Duration(hours: 23)), reference: now), '23시간 전');
    });

    test('returns "N일 전" for 1 day to 6 days', () {
      expect(relativeTime(now.subtract(const Duration(days: 1)), reference: now), '1일 전');
      expect(relativeTime(now.subtract(const Duration(days: 6)), reference: now), '6일 전');
    });

    test('returns "YYYY-MM-DD" for 7 days or more', () {
      expect(relativeTime(DateTime(2026, 5, 1), reference: now), '2026-05-01');
      expect(relativeTime(DateTime(2025, 12, 31), reference: now), '2025-12-31');
    });

    test('fromString parses ISO and falls back to "방금 전" on failure', () {
      expect(relativeTimeFromString('2026-05-13T11:55:00', reference: now), '5분 전');
      expect(relativeTimeFromString('invalid', reference: now), '방금 전');
      expect(relativeTimeFromString('', reference: now), '방금 전');
    });
  });
}
