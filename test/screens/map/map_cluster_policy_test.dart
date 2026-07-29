import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/marker/marker_constants.dart';

/// 클러스터링이 켜지는 줌 상한. `map_naver.dart` 의
/// `enableZoomRange: const NInclusiveRange(0, 16)` 와 짝이며,
/// 마지막 테스트가 둘이 어긋나지 않는지 지킨다.
const int kClusteringMaxZoom = 16;

void main() {
  test('병합 거리 표가 클러스터링 구간(0~16)을 빠짐없이, 겹치지 않게 덮는다', () {
    for (var zoom = 0; zoom <= kClusteringMaxZoom; zoom++) {
      final matched =
          kClusterMergeDistances.keys.where((r) => r.contains(zoom)).toList();
      expect(matched, hasLength(1), reason: '줌 $zoom 을 덮는 구간이 정확히 하나여야 한다');
    }
  });

  test('말풍선 minZoom 은 클러스터링 상한보다 크다', () {
    // 말풍선(충돌 숨김 켜짐)이 클러스터링 구간까지 살아 있으면 새 클러스터
    // 마커가 숨김 고착된다 (2026-07-19 마커 소실).
    expect(kBubbleMinZoom, greaterThan(kClusteringMaxZoom));
  });

  test('점↔말풍선 히스테리시스는 enter > exit > 말풍선 minZoom 순서다', () {
    expect(kTextCardEnterZoom, greaterThan(kTextCardExitZoom));
    expect(kTextCardExitZoom, greaterThan(kBubbleMinZoom));
  });

  test('클러스터 탭 줌은 클러스터링 상한을 넘어 클러스터가 확실히 풀린다', () {
    expect(kClusterTapZoom, greaterThan(kClusteringMaxZoom));
  });

  test('map_naver 의 enableZoomRange 상한이 kClusteringMaxZoom 과 일치한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    expect(
      source,
      contains('enableZoomRange: const NInclusiveRange(0, $kClusteringMaxZoom)'),
    );
  });
}
