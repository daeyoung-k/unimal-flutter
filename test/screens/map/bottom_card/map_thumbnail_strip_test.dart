import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/bottom_card/map_thumbnail_strip.dart';

void main() {
  group('stripVisibleIndices', () {
    test('그룹 5개, 현재 2번 → [0,1,2,3,4] 전체 반환', () {
      expect(stripVisibleIndices(5, 2), [0, 1, 2, 3, 4]);
    });

    test('그룹 10개, 현재 5번 → [3,4,5,6,7] 반환', () {
      expect(stripVisibleIndices(10, 5), [3, 4, 5, 6, 7]);
    });

    test('그룹 3개, 현재 0번 → [0,1,2] (왼쪽 클램프)', () {
      expect(stripVisibleIndices(3, 0), [0, 1, 2]);
    });

    test('그룹 3개, 현재 2번 → [0,1,2] (오른쪽 클램프)', () {
      expect(stripVisibleIndices(3, 2), [0, 1, 2]);
    });

    test('그룹 1개 → [0]', () {
      expect(stripVisibleIndices(1, 0), [0]);
    });

    test('그룹 2개, 현재 1번 → [0,1]', () {
      expect(stripVisibleIndices(2, 1), [0, 1]);
    });
  });
}
