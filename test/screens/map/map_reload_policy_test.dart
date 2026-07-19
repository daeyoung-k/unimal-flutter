import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/map_reload_policy.dart';

void main() {
  group('MapReloadPolicy', () {
    test('화면 짧은 변 30%를 이동 임계값으로 사용한다', () {
      final threshold = MapReloadPolicy.movementThresholdMeters(
        viewportSize: const Size(390, 844),
        meterPerDp: 2,
      );

      expect(threshold, 234);
    });

    test('초기 조회가 API 줌 변경보다 우선한다', () {
      final reason = MapReloadPolicy.spatialReason(
        initialized: false,
        currentApiZoom: 17,
        lastApiZoom: 16,
        movedMeters: 500,
        movementThresholdMeters: 100,
      );

      expect(reason, MapReloadReason.initial);
    });

    test('실제 API 줌이 바뀌면 재조회한다', () {
      final reason = MapReloadPolicy.spatialReason(
        initialized: true,
        currentApiZoom: 17,
        lastApiZoom: 16,
        movedMeters: 0,
        movementThresholdMeters: 100,
      );

      expect(reason, MapReloadReason.apiZoomChanged);
    });

    test('같은 API 줌에서 화면 30% 미만 이동은 건너뛴다', () {
      final reason = MapReloadPolicy.spatialReason(
        initialized: true,
        currentApiZoom: 17,
        lastApiZoom: 17,
        movedMeters: 99.9,
        movementThresholdMeters: 100,
      );

      expect(reason, MapReloadReason.none);
    });

    test('같은 API 줌에서 화면 30% 이상 이동은 재조회한다', () {
      final reason = MapReloadPolicy.spatialReason(
        initialized: true,
        currentApiZoom: 17,
        lastApiZoom: 17,
        movedMeters: 100,
        movementThresholdMeters: 100,
      );

      expect(reason, MapReloadReason.viewportMoved);
    });

    test('마지막 성공 후 30초부터 freshness가 만료된다', () {
      final lastSuccess = DateTime(2026, 7, 16, 12);

      expect(
        MapReloadPolicy.isFreshnessDue(
          lastSuccessfulAt: lastSuccess,
          now: lastSuccess.add(const Duration(seconds: 29)),
        ),
        isFalse,
      );
      expect(
        MapReloadPolicy.isFreshnessDue(
          lastSuccessfulAt: lastSuccess,
          now: lastSuccess.add(const Duration(seconds: 30)),
        ),
        isTrue,
      );
    });

    test('자동 조회는 앱·탭·상호작용·로딩 조건을 모두 만족해야 한다', () {
      bool allowed({
        bool resumed = true,
        bool mapTab = true,
        bool interaction = false,
        bool loading = false,
      }) => MapReloadPolicy.canAutoRefresh(
        isAppResumed: resumed,
        isMapTabActive: mapTab,
        isInteractionOpen: interaction,
        isLoading: loading,
      );

      expect(allowed(), isTrue);
      expect(allowed(resumed: false), isFalse);
      expect(allowed(mapTab: false), isFalse);
      expect(allowed(interaction: true), isFalse);
      expect(allowed(loading: true), isFalse);
    });
  });
}
