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

  test('말풍선 레이어는 일반 NMarker 이고 클러스터러블을 만들지 않는다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _syncBubbleLayer(');
    expect(start, isNonNegative);
    if (start < 0) return;
    final end = source.indexOf('/// 말풍선 일반 NMarker 생성', start);
    final method = source.substring(start, end);
    final builderStart = source.indexOf('NMarker _buildBubbleMarker(');
    final builderEnd = source.indexOf('void _closeAllCards()', builderStart);
    final builder = source.substring(builderStart, builderEnd);

    // sync 는 재조회를 트리거하지 않고, 클러스터러블 레이어를 건드리지 않는다.
    expect(method, isNot(contains('_loadMapMarkers(')));
    expect(method, isNot(contains('NOverlayType.clusterableMarker')));
    expect(method, contains('NOverlayType.marker'));
    // 재조회 중 조작 금지 (C3) + latest-wins 세대.
    expect(method, contains('if (_isLoadingMarkers) return'));
    expect(method, contains('generation != _bubbleSyncGeneration'));
    // 히스테리시스는 공용 상태 하나로 판정.
    expect(method, contains('_resolveTextCardMode(rawZoom)'));
    // 말풍선은 일반 NMarker + 점 레이어보다 위 zIndex.
    expect(builder, contains('NMarker('));
    expect(builder, isNot(contains('NClusterableMarker')));
    expect(builder, contains('300000 + post.score.toInt()'));
    // 페이드 인 시작값 — 충돌 숨김은 빌드 시점이 아니라 페이드 완료 후.
    expect(builder, contains('alpha: 0'));
    expect(builder, isNot(contains('setIsHideCollidedMarkers')));
    // 클러스터링 구간(≤16)과 공존 금지 — 네이티브 minZoom 하드 가드
    // (충돌 숨김 켜진 말풍선이 새 클러스터를 숨김 고착시키는 사고 방지).
    expect(builder, contains('setMinZoom(kBubbleMinZoom)'));
  });

  test('말풍선 전환은 페이드 트윈이고 충돌 숨김은 페이드와 교차된다', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();
    final syncStart = source.indexOf('Future<void> _syncBubbleLayer(');
    final regionEnd = source.indexOf('void _closeAllCards()', syncStart);
    final region = source.substring(syncStart, regionEnd);

    // 추가: alpha 0 add → 페이드 인 → 완료 후 충돌 숨김 on.
    final addFade = region.indexOf("_fadeBubble(id, marker, to: 1.0");
    expect(addFade, isNonNegative);
    expect(region, contains('_setBubbleCollisionHiding(marker, true)'));
    // 제거: 충돌 숨김 off → 페이드 아웃 → 완료 후 delete.
    final unhide = region.indexOf('_setBubbleCollisionHiding(marker, false)');
    final fadeOut = region.indexOf("_fadeBubble(id, marker, to: 0.0", unhide);
    final delete = region.indexOf('deleteOverlay', fadeOut);
    expect(unhide, isNonNegative);
    expect(fadeOut, greaterThan(unhide));
    expect(delete, greaterThan(fadeOut));
    // 페이드 아웃 중 재목표 시 취소 후 복귀.
    expect(region, contains('_bubbleRemovingIds.remove(id)'));
    // 트윈은 말풍선 레이어(일반 NMarker) 전용 — 재전환 시 이전 트윈 취소.
    expect(region, contains('_bubbleFadeTimers.remove(id)?.cancel()'));
    expect(region, contains('kBubbleFadeDuration'));
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
    final syncEnd = source.indexOf('/// 말풍선 일반 NMarker 생성', syncStart);
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
}
