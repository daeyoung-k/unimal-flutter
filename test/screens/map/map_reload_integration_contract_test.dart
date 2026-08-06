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

  test('레거시 in-place 전환·억제 경로가 존재하지 않는다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();

    // 2-레이어 설계(docs/specs/2026-07-19)로 대체 — 클러스터러블 마커의
    // in-place 표현 변경은 리클러스터링 되돌림(C1) 때문에 성립하지 않는다.
    expect(source, isNot(contains('_flipTextMarkerModeInPlace')));
    expect(source, isNot(contains('_fadeInMarker')));
    expect(source, isNot(contains('_alphaTweens')));
    expect(source, isNot(contains('_syncTextBubbleSuppression')));
    expect(source, isNot(contains('_restoreTextBubblesAfterClose')));
    expect(source, isNot(contains('_textBubbleRestoreIds')));
    expect(source, isNot(contains('_textMarkerCardMode')));
    expect(source, isNot(contains('_textBubblesSuppressed')));
    expect(source, isNot(contains('_isDisplayedAsCard')));
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
    // 시그니처가 async 로 바뀌었다(2026-08-06). indexOf 가 -1 이면 substring 이
    // RangeError 로 죽어 원인이 안 보이므로, 앵커를 못 찾은 것 자체를 먼저 실패시킨다.
    final pendingStart = source.indexOf('Future<void> _applyPendingLocation()');
    expect(pendingStart, isNonNegative,
        reason: '_applyPendingLocation 앵커를 찾지 못했다 — 시그니처가 바뀌었는지 확인');
    final pendingEnd = source.indexOf('@override\n  void dispose()', pendingStart);
    final pendingMethod = source.substring(pendingStart, pendingEnd);

    // boardId 가 함께 온 경로는 _focusPostOnMap 에 위임한다. 계약(raw zoom + floor
    // API zoom 을 함께 전달)은 두 경로 모두에서 지켜져야 하므로 여기도 검사한다.
    final focusStart = source.indexOf('Future<bool> _focusPostOnMap(');
    expect(focusStart, isNonNegative,
        reason: '_focusPostOnMap 앵커를 찾지 못했다 — 시그니처가 바뀌었는지 확인');
    final focusEnd = source.indexOf('Future<void> _onPostResultTap(', focusStart);
    final focusMethod = source.substring(focusStart, focusEnd);

    final locationStart = source.indexOf(
      'Future<void> _moveToCurrentLocationOrDefault()',
    );
    final locationEnd = source.indexOf(
      'Future<bool> _loadMapMarkers(',
      locationStart,
    );
    final locationMethod = source.substring(locationStart, locationEnd);

    for (final method in [pendingMethod, focusMethod]) {
      expect(method, contains('_apiZoomFor(_clusterExpandZoom)'));
      expect(method, contains('rawZoom: _clusterExpandZoom'));
      expect(method, isNot(contains('.round()')));
    }
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
      '/// 기본(비선택) 캡션',
      helperStart,
    );
    final helper = source.substring(helperStart, helperEnd);
    expect(RegExp('_onCameraIdle\\(\\)').allMatches(helper).length, 1);
    expect(
      RegExp('_consumePendingFreshness\\(\\)').allMatches(helper).length,
      1,
    );
  });

  // ── 2-레이어 말풍선 계약 (docs/specs/2026-07-19) ──────────────────────

  test('점 레이어 payload 는 항상 점 — updateMarkers 에 카드 표현 분기가 없다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf(
      'Future<_MapMarkerLoadOutcome> _loadMapMarkersInternal(',
    );
    final end = source.indexOf(
      'Future<void> _clearStoryMarkerOverlaysAndCaches()',
      start,
    );
    final method = source.substring(start, end);

    // 클러스터러블 마커에 카드 아이콘·in-place 전환 금지 (C1 되돌림).
    expect(method, isNot(contains('_buildTextCardIcon(')));
    expect(method, isNot(contains('_flipTextMarkerModeInPlace(')));
    expect(method, isNot(contains('textCardMode')));
    // canCard 태그(탭 줌 유도)는 유지 — 말풍선 레이어와 같은 판정 헬퍼 사용.
    expect(method, contains('_textBubbleEligibleIds('));
    expect(method, contains("'canCard': canBecomeCard ? '1' : '0'"));
  });

  test('공용 말풍선 레이어는 일반 NMarker 이고 클러스터러블을 만들지 않는다', () {
    final layer = File('lib/screens/map/marker/bubble_marker_layer.dart')
        .readAsStringSync();
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _syncBubbleLayer(');
    expect(start, isNonNegative);
    if (start < 0) return;
    final end = source.indexOf('void _closeAllCards()', start);
    final method = source.substring(start, end);

    // 화면 sync 는 재조회를 트리거하지 않고 목표 집합만 계산해 레이어에 위임.
    expect(method, isNot(contains('_loadMapMarkers(')));
    expect(method, contains('if (_isLoadingMarkers) return'));
    expect(method, contains('_resolveTextCardMode(rawZoom)'));
    expect(method, contains('_bubbleLayer.sync('));
    // 레이어는 클러스터러블을 만들지도 건드리지도 않는다.
    expect(layer, isNot(contains('NClusterableMarker')));
    expect(layer, contains('NOverlayType.marker'));
    // latest-wins 세대 + 일반 NMarker + 점 레이어보다 위 zIndex.
    expect(layer, contains('generation != _syncGeneration'));
    expect(layer, contains('300000 + target.score'));
    // 페이드 인 시작값 — 충돌 숨김은 빌드 시점이 아니라 페이드 완료 후.
    expect(layer, contains('alpha: 0'));
    // 클러스터링 구간(≤16)과 공존 금지 — 네이티브 minZoom 하드 가드
    // (충돌 숨김 켜진 말풍선이 새 클러스터를 숨김 고착시키는 사고 방지).
    expect(layer, contains('setMinZoom(kBubbleMinZoom)'));
  });

  test('말풍선은 페이드 트윈으로 전환하고 점 마커를 가리지 않는다', () {
    final layer = File('lib/screens/map/marker/bubble_marker_layer.dart')
        .readAsStringSync();

    // 1. 페이드 트윈은 유지된다 — 추가 시 alpha 0→1, 제거 시 1→0.
    final fadeIn = layer.indexOf('_fade(id, marker, to: 1.0');
    final fadeOut = layer.indexOf('_fade(id, marker, to: 0.0');
    expect(fadeIn, isNonNegative);
    expect(fadeOut, isNonNegative);
    expect(layer, contains('kBubbleFadeDuration'));

    // 2. 제거 순서: 페이드 아웃 → delete. 페이드가 끝난 뒤 지워야 시트가
    // 툭 사라지지 않고 자연스럽게 없어진다.
    final delete = layer.indexOf('deleteOverlay', fadeOut);
    expect(delete, greaterThan(fadeOut));

    // 3. setIsHideCollidedMarkers(false) — 점 마커를 가리지 않는다.
    // 이번 설계 전환(2026-07-29)의 핵심: 말풍선 아이콘 하단이 투명해
    // 그 자리에 실제 점이 보여야 하므로, true 로 되돌아가면 점이
    // 아예 사라진다. 절대 true 로 바뀌면 안 된다.
    expect(layer, contains('marker.setIsHideCollidedMarkers(false)'));

    // 4. setIsHideCollidedCaptions(true) 는 존재하되 빌드 시점(1회) 설정
    // 이지 더 이상 페이드 완료 훅이 아니다 — "카드(204dp)와 겹치는
    // 다른 마커의 캡션" 정리 전용. 점 자신의 제목 캡션 억제는 여기가
    // 아니라 NOverlayCaption.maxZoom(네이티브, kTextCardEnterZoom)이
    // 담당한다 — 두 마커 모두 앵커가 (0.5,1.0)이라 아이콘은 좌표 위쪽,
    // 캡션은 좌표 아래쪽으로 뻗어 애초에 충돌 판정이 걸리지 않기 때문.
    expect(layer, contains('marker.setIsHideCollidedCaptions(true)'));

    // 5. _setCollisionHiding 헬퍼(페이드에 맞춰 마커 숨김을 토글하던 옛
    // 경로)는 재도입 금지 계약이다 — 다시 나타나면 점이 사라지는 사고로
    // 되돌아간다.
    expect(layer, isNot(contains('_setCollisionHiding')));

    // 6. 페이드 아웃 중 재목표 시 취소 후 복귀.
    expect(layer, contains('_removingIds.remove(id)'));

    // 7. 재전환 시 이전 트윈 취소 후 현재 alpha 에서 이어감.
    expect(layer, contains('_fadeTimers.remove(id)?.cancel()'));
  });

  test('메인 지도와 내지도가 같은 말풍선 레이어를 쓴다', () {
    final main = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final myMap = File('lib/screens/profile/mypage/my_story_map_screen.dart')
        .readAsStringSync();

    expect(main, contains('_bubbleLayer.sync('));
    expect(myMap, contains('_bubbleLayer.sync('));
    // 내지도의 구 in-place 일괄 교체는 폐기 — C1 되돌림 때문에 재도입 금지.
    expect(myMap, isNot(contains('_applyTextCardMode')));
    expect(myMap, isNot(contains('_textCardIconCache')));
    // 밀집 필터도 양쪽 공통 — 없으면 뭉친 글의 카드 충돌 숨김이 주변
    // 마커를 전부 가린다 (2026-07-19 내지도 마커 소실).
    expect(main, contains('kTextCardDenseNeighbors'));
    expect(myMap, contains('kTextCardDenseNeighbors'));
  });

  test('idle 은 공간 재조회 판단 전에 말풍선 레이어를 동기화한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _onCameraIdle()');
    final end = source.indexOf('int _apiZoomFor(', start);
    final method = source.substring(start, end);
    final sync = method.indexOf('_syncBubbleLayer(');
    final spatial = method.indexOf('MapReloadPolicy.spatialReason');

    expect(sync, isNonNegative);
    expect(spatial, greaterThan(sync));
  });

  test('재조회 성공 후 로딩 해제 뒤에 말풍선 레이어를 수렴시킨다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> _loadMapMarkers(');
    final end = source.indexOf(
      'Future<_MapMarkerLoadOutcome> _loadMapMarkersInternal(',
      start,
    );
    final method = source.substring(start, end);
    final loadingCleared = method.indexOf('_isLoadingMarkers = false');
    final converge = method.indexOf(
      'unawaited(_syncBubbleLayerWithCurrentCamera())',
    );
    final returnOutcome = method.indexOf(
      'return outcome == _MapMarkerLoadOutcome.applied',
    );

    expect(loadingCleared, isNonNegative);
    expect(converge, greaterThan(loadingCleared));
    expect(returnOutcome, greaterThan(converge));
  });

  test('카드 열림은 말풍선 레이어를 비우고 닫힘 idle 이 복원한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final selectStart = source.indexOf('Future<void> _selectMarker(');
    final selectEnd = source.indexOf('// ── 스택 원형 펼침', selectStart);
    final select = source.substring(selectStart, selectEnd);
    final syncStart = source.indexOf('Future<void> _syncBubbleLayer(');
    final syncEnd = source.indexOf('void _closeAllCards()', syncStart);
    final sync = source.substring(syncStart, syncEnd);

    // 열림: sync 호출 (선택 중엔 목표 공집합 → 전부 제거).
    expect(select, contains('_syncBubbleLayerWithCurrentCamera()'));
    expect(sync, contains('_selectedGroupIndex == null'));
    // 닫힘: 기존 resume 경로의 _onCameraIdle 이 sync 를 다시 부른다.
    expect(source, contains('await _onCameraIdle()'));
  });

  test('카드 close는 idle 재평가로 말풍선을 복원하고 pending을 소비한다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final helperStart = source.indexOf(
      'Future<void> _resumeAutomaticReloadsAfterInteractionClose(',
    );
    expect(helperStart, isNonNegative);
    if (helperStart < 0) return;
    final helperEnd = source.indexOf(
      '/// 기본(비선택) 캡션',
      helperStart,
    );
    final helper = source.substring(helperStart, helperEnd);
    final idle = helper.indexOf('await _onCameraIdle()');
    final pending = helper.indexOf('await _consumePendingFreshness()');

    // 말풍선 복원은 별도 경로가 아니라 idle 내부의 말풍선 레이어 sync 가
    // 담당한다 (2-레이어: 선택 해제 후 현재 줌 기준 재구성).
    expect(idle, isNonNegative);
    expect(pending, greaterThan(idle));
  });

  test('마커 선택과 지도 탭은 피드 카드를 함께 닫는다', () {
    final map = File('lib/screens/map/map_naver.dart').readAsStringSync();

    // 피드 카드는 화면 하단만 덮고 상단 지도는 여전히 탭 가능하다. 두 경로에서
    // _feedSelectedPost 를 지우지 않으면 MapBottomCard 두 개가 동시에 마운트되고,
    // 지도 탭으로 피드 카드가 닫히지 않는다 (2026-07-30 최종 리뷰).
    final closeAll = map.indexOf('void _closeAllCards()');
    expect(closeAll, isNonNegative);
    final selectMarker = map.indexOf('Future<void> _selectMarker(');
    expect(selectMarker, isNonNegative);

    // 각 함수 본문 안에서 피드 카드 상태가 초기화되는지 확인한다.
    // (함수 시작 위치 이후 가장 가까운 초기화 지점이 그 함수 안에 있는지)
    for (final entry in {
      '_closeAllCards': closeAll,
      '_selectMarker': selectMarker,
    }.entries) {
      final clearIdx = map.indexOf('_feedSelectedPost = null', entry.value);
      expect(clearIdx, isNonNegative,
          reason: '${entry.key} 가 _feedSelectedPost 를 지우지 않는다');
      // 다음 최상위 메서드 선언보다 앞에 있어야 그 함수 안이다.
      final nextMethod = map.indexOf('\n  Future<', entry.value + 1);
      final nextVoid = map.indexOf('\n  void ', entry.value + 1);
      final bound = [nextMethod, nextVoid]
          .where((i) => i >= 0)
          .fold<int>(map.length, (a, b) => a < b ? a : b);
      expect(clearIdx, lessThan(bound),
          reason: '${entry.key} 본문 밖에서 초기화되고 있다');
    }
  });
}
