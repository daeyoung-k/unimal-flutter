import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('강제 갱신은 응답 전에 오버레이를 삭제하지 않는다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _doForceRefresh()');
    final end = source.indexOf(
      'Future<void> _moveToCurrentLocationOrDefault()',
      start,
    );
    final method = source.substring(start, end);

    expect(method, isNot(contains('deleteOverlay')));
    expect(method, contains('forceRebuild: true'));
  });

  test('카메라 idle은 표현 모드가 아닌 공간 정책으로 재조회한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _onCameraIdle()');
    final end = source.indexOf('int _apiZoomFor(', start);
    final method = source.substring(start, end);

    expect(method, contains('MapReloadPolicy.spatialReason'));
    expect(method, contains('_apiZoomFor(currentZoom)'));
    expect(method, contains('MapReloadPolicy.cameraDebounce'));
    expect(method, isNot(contains('_peekTextCardMode')));
    expect(method, isNot(contains('abs() >= 1')));
    expect(method, isNot(contains('dLat > 0.0005')));
  });

  test('카드 닫힘 말풍선 복원은 로컬 마커만 갱신한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf(
      'Future<void> _restoreTextBubblesAfterClose()',
    );
    final end = source.indexOf('/// 마커 페이드인', start);
    final method = source.substring(start, end);

    expect(method, contains('_syncTextBubbleSuppression'));
    expect(method, contains('_restoreTextBubbleMarkersInPlace'));
    expect(method, isNot(contains('_loadMapMarkers')));
    expect(method, isNot(contains('addOverlay')));
    expect(method, isNot(contains('getCameraPosition')));
    expect(method, contains('_postGroups'));
    expect(method, contains('_markerRefs'));
    expect(method, contains('_flipTextMarkerModeInPlace'));
  });

  test('지도는 성공 기준 one-shot freshness와 생명주기 게이트를 사용한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();

    expect(source, contains('Timer? _freshnessTimer'));
    expect(source, contains('DateTime? _lastSuccessfulMapRefreshAt'));
    expect(source, contains('MapReloadPolicy.freshnessInterval'));
    expect(source, contains('MapReloadPolicy.failureRetryInterval'));
    expect(source, contains('MapReloadPolicy.canAutoRefresh'));
    expect(source, contains('didChangeAppLifecycleState'));
    expect(source, contains('NavController>().selectedIndex'));
    expect(
      source,
      isNot(contains('Timer.periodic(MapReloadPolicy.freshnessInterval')),
    );
  });

  test('resume은 due 여부와 무관하게 보류 자동 조회를 소비한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('void didChangeAppLifecycleState(');
    final end = source.indexOf(
      'Future<void> _reloadMarkersForBrightnessChange()',
      start,
    );
    final method = source.substring(start, end);
    final dueStart = method.indexOf('if (due)');
    final dueEnd = method.indexOf('\n    }', dueStart);
    final consume = method.indexOf('unawaited(_consumePendingFreshness())');

    expect(method, contains('_deferFreshness(MapReloadReason.appResumed)'));
    expect(consume, greaterThan(dueEnd));
  });

  test('spatial 자동 조회는 reason 계산 후 즉시와 debounce 시점에 gate한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _onCameraIdle()');
    final end = source.indexOf('int _apiZoomFor(', start);
    final method = source.substring(start, end);
    final reason = method.indexOf('MapReloadPolicy.spatialReason');
    final gate = method.indexOf('if (!_canAutoRefresh)', reason);
    final timer = method.indexOf(
      '_cameraDebounce = Timer(MapReloadPolicy.cameraDebounce',
    );
    expect(gate, greaterThan(reason));
    expect(timer, isNonNegative);
    if (gate < 0 || timer < 0) return;
    final timerMethod = method.substring(timer);
    final timerGate = timerMethod.indexOf('if (!_canAutoRefresh)');
    final load = timerMethod.indexOf('_loadMapMarkers(');

    expect(method.substring(gate, timer), contains('_deferFreshness(reason)'));
    expect(timerGate, isNonNegative);
    expect(load, greaterThan(timerGate));
    expect(
      timerMethod.substring(timerGate, load),
      contains('_deferFreshness(reason)'),
    );
  });

  test('현재 카메라 자동 조회는 성공 세대와 카메라 예외 재시도를 보호한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf(
      'Future<void> _reloadCurrentCamera(MapReloadReason reason)',
    );
    final end = source.indexOf('// 검색바 우측', start);
    final method = source.substring(start, end);

    expect(source, contains('int _successfulMapRefreshGeneration'));
    expect(method, contains('final refreshGeneration'));
    expect(
      method,
      contains('refreshGeneration != _successfulMapRefreshGeneration'),
    );
    expect(method, contains('catch (e)'));
    expect(method, contains('_deferFreshness(reason)'));
    expect(method, contains('MapReloadPolicy.failureRetryInterval'));
  });

  test('로드 중 새로 생긴 보류 reason은 이전 응답 성공이 지우지 않는다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> _loadMapMarkers(');
    final end = source.indexOf(
      'Future<_MapMarkerLoadOutcome> _loadMapMarkersInternal(',
      start,
    );
    final method = source.substring(start, end);

    expect(source, contains('int _pendingAutoRefreshGeneration'));
    expect(method, contains('final pendingGenerationAtStart'));
    expect(method, contains('final hasNewerPending'));
    expect(
      method,
      contains('pendingGenerationAtStart != _pendingAutoRefreshGeneration'),
    );
    expect(method, contains('final preserveSpatialPending'));
  });

  test('stack transition의 마지막 blocker 해제 후 보류 자동 조회를 소비한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();

    expect(source, contains('void _finishStackExpansion(int seq)'));
    final finishStart = source.indexOf('void _finishStackExpansion(int seq)');
    if (finishStart < 0) return;
    final finishEnd = source.indexOf('void _followStackFanPost(', finishStart);
    final finishMethod = source.substring(finishStart, finishEnd);
    final collapseStart = source.indexOf('Future<void> _collapseStackFan(');
    final collapseEnd = source.indexOf(
      'void _onCardDragUpdate(',
      collapseStart,
    );
    final collapseMethod = source.substring(collapseStart, collapseEnd);

    expect(finishMethod, contains('_expandingStackId = null'));
    expect(finishMethod, contains('_consumePendingFreshness'));
    expect(
      RegExp('_consumePendingFreshness').allMatches(collapseMethod).length,
      greaterThanOrEqualTo(3),
    );
  });

  test('failure retry pending은 not-before 전에는 남은 시간만 재예약한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _consumePendingFreshness()');
    final end = source.indexOf(
      'Future<void> _reloadCurrentCamera(MapReloadReason reason)',
      start,
    );
    final method = source.substring(start, end);
    final remaining = method.indexOf('final remaining');
    final schedule = method.indexOf('_scheduleFreshness(delay: remaining)');
    final clear = method.indexOf('_freshnessRefreshPending = false');

    expect(source, contains('DateTime? _pendingAutoRefreshNotBefore'));
    expect(method, contains('notBefore.difference(DateTime.now())'));
    expect(remaining, isNonNegative);
    expect(schedule, greaterThan(remaining));
    expect(clear, greaterThan(schedule));
    expect(
      RegExp('notBefore: DateTime\\.now\\(\\)\\.add').allMatches(source).length,
      greaterThanOrEqualTo(3),
    );
  });

  test('성공은 retry pending을 지우고 더 최신 spatial pending만 보존한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> _loadMapMarkers(');
    final end = source.indexOf(
      'Future<_MapMarkerLoadOutcome> _loadMapMarkersInternal(',
      start,
    );
    final method = source.substring(start, end);

    expect(source, contains('bool _isSpatialReloadReason('));
    expect(method, contains('final hasNewerPending'));
    expect(method, contains('final preserveSpatialPending'));
    expect(method, contains('_isSpatialReloadReason(_pendingFreshnessReason)'));
    expect(method, contains('_pendingAutoRefreshNotBefore = null'));
    expect(method, contains('if (!preserveSpatialPending)'));
  });

  test('로드 finally는 force와 queued 요청 이후에만 pending을 drain한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> _loadMapMarkers(');
    final end = source.indexOf(
      'Future<_MapMarkerLoadOutcome> _loadMapMarkersInternal(',
      start,
    );
    final method = source.substring(start, end);
    final loadingCleared = method.indexOf('_isLoadingMarkers = false');
    final force = method.indexOf('if (_pendingForceRefresh && mounted)');
    final queued = method.indexOf(
      'else if (_pendingReloadArgs != null && mounted)',
    );
    final drain = method.lastIndexOf('_consumePendingFreshness()');

    expect(loadingCleared, isNonNegative);
    expect(force, greaterThan(loadingCleared));
    expect(queued, greaterThan(force));
    expect(drain, greaterThan(queued));
  });

  test('stack expansion은 try-finally로 blocker를 정확히 한 번 해제한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _expandStackFan(');
    final end = source.indexOf('void _finishStackExpansion(int seq)', start);
    final method = source.substring(start, end);
    final blocker = method.indexOf('_expandingStackId = stackId');
    final tryStart = method.indexOf('try {', blocker);
    final finallyStart = method.lastIndexOf('finally {');
    final finish = method.lastIndexOf('_finishStackExpansion(seq)');

    expect(tryStart, greaterThan(blocker));
    expect(finallyStart, greaterThan(tryStart));
    expect(finish, greaterThan(finallyStart));
    expect(
      RegExp('_finishStackExpansion\\(seq\\)').allMatches(method).length,
      1,
    );
  });

  test('spatial idle은 debounce 전과 callback에서 live cooldown을 pending으로 보낸다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _onCameraIdle()');
    final end = source.indexOf('int _apiZoomFor(', start);
    final method = source.substring(start, end);
    final reason = method.indexOf('MapReloadPolicy.spatialReason');
    final timer = method.indexOf(
      '_cameraDebounce = Timer(MapReloadPolicy.cameraDebounce',
    );
    final load = method.indexOf('_loadMapMarkers(', timer);

    expect(source, contains('bool get _hasLiveAutoRefreshCooldown'));
    expect(timer, greaterThan(reason));
    expect(load, greaterThan(timer));
    expect(
      RegExp('_hasLiveAutoRefreshCooldown').allMatches(method).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      method.substring(reason, timer),
      contains('_consumePendingFreshness()'),
    );
    expect(
      method.substring(timer, load),
      contains('_consumePendingFreshness()'),
    );
  });

  test('spatial defer는 기존 recovery not-before를 보존한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('void _deferFreshness(');
    final end = source.indexOf('void _onFreshnessDue()', start);
    final method = source.substring(start, end);

    expect(method, contains('final existingNotBefore'));
    expect(
      method,
      contains('_pendingAutoRefreshNotBefore = existingNotBefore'),
    );
    expect(method, isNot(contains('else if (_isSpatialReloadReason(reason))')));
  });

  test('queued reload는 요청 시점 pending generation을 저장하고 재생한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> _loadMapMarkers(');
    final end = source.indexOf(
      'Future<_MapMarkerLoadOutcome> _loadMapMarkersInternal(',
      start,
    );
    final method = source.substring(start, end);

    expect(source, contains('int pendingGenerationAtRequest,'));
    expect(method, contains('int? pendingGenerationAtRequest'));
    expect(
      method,
      contains('pendingGenerationAtRequest ?? _pendingAutoRefreshGeneration'),
    );
    expect(
      method,
      contains('pendingGenerationAtRequest: args.pendingGenerationAtRequest'),
    );
  });

  test('pending consume은 dispose 후 not-before timer를 재예약하지 않는다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _consumePendingFreshness()');
    final end = source.indexOf(
      'Future<void> _reloadCurrentCamera(MapReloadReason reason)',
      start,
    );
    final method = source.substring(start, end);
    final mountedGuard = method.indexOf('if (!mounted');
    final notBefore = method.indexOf('final notBefore');
    final schedule = method.indexOf('_scheduleFreshness(delay: remaining)');

    expect(mountedGuard, isNonNegative);
    expect(notBefore, greaterThan(mountedGuard));
    expect(schedule, greaterThan(notBefore));
  });

  test('자동 응답은 fetch 후 적용 gate에서 deferred outcome으로 분리된다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final outerStart = source.indexOf('Future<bool> _loadMapMarkers(');
    final innerStart = source.indexOf(
      'Future<_MapMarkerLoadOutcome> _loadMapMarkersInternal(',
      outerStart,
    );

    expect(source, contains('enum _MapMarkerLoadOutcome'));
    expect(source, contains('applied'));
    expect(source, contains('transportFailure'));
    expect(source, contains('deferred'));
    expect(innerStart, isNonNegative);
    if (innerStart < 0) return;

    final outer = source.substring(outerStart, innerStart);
    final innerEnd = source.indexOf(
      'Future<void> _clearStoryMarkerOverlaysAndCaches()',
      innerStart,
    );
    final inner = source.substring(innerStart, innerEnd);
    final fetch = inner.indexOf('getMapLocationPosts(');
    final responseGate = inner.indexOf(
      '_isAutomaticReloadReason(reason) && !_canApplyAutomaticResponse',
    );
    final forceRebuild = inner.indexOf('if (forceRebuild)');

    expect(fetch, isNonNegative);
    expect(responseGate, greaterThan(fetch));
    expect(forceRebuild, greaterThan(responseGate));
    expect(
      inner.substring(responseGate, forceRebuild),
      contains('_MapMarkerLoadOutcome.deferred'),
    );
    expect(outer, contains('_MapMarkerLoadOutcome.transportFailure'));
    expect(outer, contains('_MapMarkerLoadOutcome.deferred'));
    final deferredBranch = outer.indexOf(
      'outcome == _MapMarkerLoadOutcome.deferred',
    );
    final transportBranch = outer.indexOf(
      'outcome == _MapMarkerLoadOutcome.transportFailure',
      deferredBranch,
    );
    expect(deferredBranch, isNonNegative);
    expect(transportBranch, greaterThan(deferredBranch));
    expect(
      outer.substring(deferredBranch, transportBranch),
      isNot(contains('failureRetryInterval')),
    );
  });

  test('프로그램 카메라 로드는 raw zoom과 floor API zoom을 함께 전달한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final pendingStart = source.indexOf('void _applyPendingLocation()');
    final pendingEnd = source.indexOf('@override\n  void dispose()', pendingStart);
    final pendingMethod = source.substring(pendingStart, pendingEnd);
    final locationStart = source.indexOf(
      'Future<void> _moveToCurrentLocationOrDefault()',
    );
    final locationEnd = source.indexOf(
      'Future<bool> _loadMapMarkers(',
      locationStart,
    );
    final locationMethod = source.substring(locationStart, locationEnd);

    expect(pendingMethod, contains('_apiZoomFor(_clusterExpandZoom)'));
    expect(pendingMethod, contains('rawZoom: _clusterExpandZoom'));
    expect(pendingMethod, isNot(contains('.round()')));
    expect(
      RegExp('_apiZoomFor\\(_defaultEntryZoom\\)')
          .allMatches(locationMethod)
          .length,
      5,
    );
    expect(
      RegExp('rawZoom: _defaultEntryZoom').allMatches(locationMethod).length,
      5,
    );
    expect(locationMethod, isNot(contains('.round()')));
    expect(locationMethod, isNot(contains(', 15)')));
  });

  test('검색 interaction 해제는 pending과 spatial 재평가를 한 번 재개한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final clearStart = source.indexOf('void _clearSearch()');
    final clearEnd = source.indexOf(
      'Future<void> _onSymbolTapped(',
      clearStart,
    );
    final clearMethod = source.substring(clearStart, clearEnd);
    final blockerCleared = clearMethod.indexOf('_selectedPlace = null');
    final resume = clearMethod.indexOf(
      '_resumeAutomaticReloadsAfterInteractionClose()',
    );
    final helperStart = source.indexOf(
      'Future<void> _resumeAutomaticReloadsAfterInteractionClose(',
    );

    expect(resume, greaterThan(blockerCleared));
    expect(helperStart, isNonNegative);
    if (helperStart < 0) return;
    final helperEnd = source.indexOf(
      '/// 마커가 현재 "말풍선 카드"',
      helperStart,
    );
    final helper = source.substring(helperStart, helperEnd);
    expect(RegExp('_onCameraIdle\\(\\)').allMatches(helper).length, 1);
    expect(
      RegExp('_consumePendingFreshness\\(\\)').allMatches(helper).length,
      1,
    );
  });

  test('카드 close는 말풍선 복원 후 재조회하고 stale marker 전환을 버린다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final helperStart = source.indexOf(
      'Future<void> _resumeAutomaticReloadsAfterInteractionClose(',
    );
    expect(helperStart, isNonNegative);
    if (helperStart < 0) return;
    final helperEnd = source.indexOf(
      '/// 마커가 현재 "말풍선 카드"',
      helperStart,
    );
    final helper = source.substring(helperStart, helperEnd);
    final restore = helper.indexOf('await _restoreTextBubblesAfterClose()');
    final idle = helper.indexOf('await _onCameraIdle()');
    final pending = helper.indexOf('await _consumePendingFreshness()');

    expect(restore, isNonNegative);
    expect(idle, greaterThan(restore));
    expect(pending, greaterThan(idle));
    expect(
      RegExp('restoreTextBubbles: true').allMatches(source).length,
      greaterThanOrEqualTo(2),
    );

    final flipStart = source.indexOf(
      'Future<bool> _flipTextMarkerModeInPlace(',
    );
    final flipEnd = source.indexOf('Future<NOverlayImage> _buildTextCardIcon(', flipStart);
    final flip = source.substring(flipStart, flipEnd);
    final iconReady = flip.indexOf('if (!mounted');
    final identity = flip.indexOf(
      'identical(_markerRefs[post.id], marker)',
      iconReady,
    );
    final apply = flip.indexOf('marker.setAlpha(0)', iconReady);

    expect(identity, greaterThan(iconReady));
    expect(apply, greaterThan(identity));
    expect(
      flip.substring(iconReady, apply),
      contains('_mapMarkerIds.contains(post.id)'),
    );
    expect(flip.substring(iconReady, apply), contains('marker.isAdded'));
  });
}
