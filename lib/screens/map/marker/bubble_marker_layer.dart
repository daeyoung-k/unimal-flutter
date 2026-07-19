import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:unimal/screens/map/marker/marker_constants.dart';

/// 말풍선 레이어 목표 1건 — 화면이 글 모델(MapPost/BoardPost)에 관계없이
/// 필요한 값만 넘긴다. [position]은 화면이 실제 마커를 그린 좌표
/// (jitter 적용 포함)와 같아야 말풍선 꼬리가 점 위에 정확히 겹친다.
class BubbleMarkerTarget {
  const BubbleMarkerTarget({
    required this.id,
    required this.position,
    required this.buildIcon,
    required this.onTap,
    this.score = 0,
  });

  /// 글 식별자 — 오버레이 id 는 레이어가 `bubble_` prefix 를 붙인다.
  final String id;
  final NLatLng position;

  /// 카드 아이콘 비동기 생성 (overlayImageFromWidget 등).
  final Future<NOverlayImage> Function() buildIcon;
  final void Function() onTap;

  /// zIndex 위계 (300000 + score) — 점 레이어(200000+score)보다 항상 위.
  final int score;
}

/// 점↔말풍선 2-레이어 설계(docs/specs/2026-07-19)의 말풍선 레이어 공용 구현.
/// 메인 지도(map_naver)와 내지도(my_story_map_screen)가 함께 쓴다.
///
/// 핵심 계약:
/// - 말풍선은 **일반 NMarker** — 네이티브 클러스터러가 관여하지 않아
///   리클러스터링 payload 되돌림(C1)이 없고 alpha 트윈이 안전하다.
/// - 같은 id 재생성이 없어 delete/add 탭 핸들러 경합(C2)도 없다.
/// - 클러스터러블 마커에는 이 레이어의 어떤 기법도 적용 금지.
/// - `minZoom(kBubbleMinZoom)` 하드 가드 — 클러스터링 구간(≤16)과 공존하면
///   충돌 숨김이 새 클러스터 마커를 숨김 고착시킨다 (2026-07-19 사고).
class BubbleMarkerLayer {
  BubbleMarkerLayer({this.debugLabel = 'bubble'});

  final String debugLabel;

  final Map<String, NMarker> _refs = {};
  final Set<String> _ids = {};
  // 페이드 아웃 진행 중(삭제 예정) — 다시 목표가 되면 취소 후 복귀.
  final Set<String> _removingIds = {};
  // 페이드 트윈 — id 별 진행 중 타이머와 현재 alpha.
  final Map<String, Timer> _fadeTimers = {};
  final Map<String, double> _alpha = {};
  // latest-wins 세대 — 비동기 아이콘 생성 중 새 sync 가 시작되면 폐기.
  int _syncGeneration = 0;

  String _overlayId(String id) => 'bubble_$id';

  /// 말풍선 집합을 [targets]로 수렴시킨다. 불일치가 없으면 no-op.
  /// - 제거분: 충돌 숨김 해제 → 페이드 아웃 → 삭제 (점이 밑에서 먼저 복귀).
  /// - 추가분: 아이콘 전부 준비 → alpha 0 일괄 add → 페이드 인 → 충돌 숨김.
  /// - [canApply]: 비동기 아이콘 생성 뒤 add 직전에 재검증되는 화면 가드
  ///   (mounted, 재조회 중 아님, 바텀 카드 닫힘 등). 제거분에는 적용하지
  ///   않는다 — 카드 열림 등으로 목표가 비어도 제거는 진행돼야 한다.
  Future<void> sync({
    required NaverMapController controller,
    required List<BubbleMarkerTarget> targets,
    required bool Function() canApply,
  }) async {
    final generation = ++_syncGeneration;
    final targetById = {for (final t in targets) t.id: t};

    // 제거분 — 페이드 중 다시 목표가 되면 취소하고 현재 alpha 에서 복귀.
    var removeStarted = 0;
    for (final id in _ids.toList()) {
      final marker = _refs[id];
      if (marker == null) continue;
      if (targetById.containsKey(id)) {
        if (_removingIds.remove(id)) {
          _fade(id, marker, to: 1.0, onDone: () {
            _setCollisionHiding(marker, true);
          });
        }
        continue;
      }
      if (_removingIds.contains(id)) continue; // 이미 페이드 아웃 중
      _removingIds.add(id);
      removeStarted++;
      // 점이 먼저 자연스럽게 돌아오도록 충돌 숨김을 풀고 페이드 아웃.
      _setCollisionHiding(marker, false);
      _fade(id, marker, to: 0.0, onDone: () {
        if (!identical(_refs[id], marker)) return;
        try {
          controller.deleteOverlay(
            NOverlayInfo(type: NOverlayType.marker, id: _overlayId(id)),
          );
        } catch (_) {/* 네이티브에서 이미 제거된 경우 무시 */}
        _ids.remove(id);
        _refs.remove(id);
        _removingIds.remove(id);
        _alpha.remove(id);
      });
    }

    // 추가분 — 아이콘을 전부 준비한 뒤 일괄 add (프레임/리클러스터링 최소화).
    final addIds =
        targetById.keys.where((id) => !_ids.contains(id)).toList();
    if (addIds.isEmpty) {
      if (removeStarted > 0 && kDebugMode) {
        debugPrint('[$debugLabel] sync -$removeStarted');
      }
      return;
    }
    final built = <String, NMarker>{};
    for (final id in addIds) {
      final target = targetById[id]!;
      final NOverlayImage icon;
      try {
        icon = await target.buildIcon();
      } catch (e) {
        debugPrint('[$debugLabel] 아이콘 생성 실패 $id: $e');
        continue; // 이 글만 생략 — 점은 그대로 보인다.
      }
      if (generation != _syncGeneration || !canApply()) {
        return; // 더 최신 sync 시작 또는 화면 상태 변화 — 이번 결과 폐기.
      }
      built[id] = _buildMarker(target, icon);
    }
    if (built.isEmpty) return;
    if (generation != _syncGeneration || !canApply()) return;
    try {
      await controller.addOverlayAll(built.values.toSet());
    } catch (e) {
      debugPrint('[$debugLabel] add 실패: $e'); // 다음 sync 가 재시도
      return;
    }
    for (final entry in built.entries) {
      final id = entry.key;
      final marker = entry.value;
      _ids.add(id);
      _refs[id] = marker;
      // alpha 0 payload 로 추가됐다 — 페이드 인 후 충돌 숨김을 켠다.
      // (숨김을 먼저 켜면 점이 즉시 사라져 페이드 동안 빈 자리가 보인다)
      _alpha[id] = 0.0;
      _fade(id, marker, to: 1.0, onDone: () {
        _setCollisionHiding(marker, true);
      });
    }
    if (kDebugMode) {
      debugPrint('[$debugLabel] sync +${built.length} -$removeStarted');
    }
  }

  /// 말풍선 일반 NMarker 생성 — 아이콘은 카드+아래 점 합성이라 기본 앵커
  /// (0.5, 1.0) 기준으로 밑의 점 마커 위에 정확히 겹친다.
  NMarker _buildMarker(BubbleMarkerTarget target, NOverlayImage icon) {
    final marker = NMarker(
      id: _overlayId(target.id),
      position: target.position,
      icon: icon,
      size: kTextCardSize,
      // 페이드 인 시작값 — add 직후 _fade 가 1.0 으로 올린다.
      alpha: 0,
    );
    // 점 레이어(200000+score)보다 항상 위.
    marker.setGlobalZIndex(300000 + target.score);
    // 클러스터링 구간(≤16)과의 공존 금지 — 줌아웃 제스처 중 idle 전에
    // 클러스터러가 재편성되면 충돌 숨김이 켜진 말풍선이 새 클러스터를
    // 숨김 고착시킨다 (2026-07-19 마커 소실). 네이티브 minZoom 으로
    // Dart sync 타이밍과 무관하게 원천 차단한다.
    marker.setMinZoom(kBubbleMinZoom);
    marker.setIsMinZoomInclusive(true);
    // 밑의 점 마커(+제목 캡션) 충돌 숨김은 여기서 켜지 않는다 —
    // 페이드 인 완료 후 _setCollisionHiding 이 켠다.
    marker.setOnTapListener((_) => target.onTap());
    return marker;
  }

  /// 말풍선 alpha 트윈 (33ms 스텝, easeOutQuad). 같은 id 재호출 시 이전
  /// 트윈을 취소하고 현재 alpha 에서 이어간다.
  void _fade(
    String id,
    NMarker marker, {
    required double to,
    VoidCallback? onDone,
  }) {
    _fadeTimers.remove(id)?.cancel();
    final double from = _alpha[id] ?? (to >= 1.0 ? 0.0 : 1.0);
    if (from == to) {
      onDone?.call();
      return;
    }
    final int steps = max(3, kBubbleFadeDuration.inMilliseconds ~/ 33);
    int step = 0;
    _fadeTimers[id] = Timer.periodic(const Duration(milliseconds: 33), (t) {
      step++;
      final double p = step / steps;
      final double eased = 1 - pow(1 - p, 2).toDouble(); // easeOutQuad
      final double value = from + (to - from) * eased;
      bool done = step >= steps;
      try {
        marker.setAlpha(done ? to : value);
        _alpha[id] = done ? to : value;
      } catch (_) {
        done = true; // 네이티브에서 제거됨 — 트윈 중단
      }
      if (done) {
        t.cancel();
        _fadeTimers.remove(id);
        onDone?.call();
      }
    });
  }

  /// 밑의 점 마커(+캡션) 충돌 숨김 토글 — 페이드 인 완료 후 켜고,
  /// 페이드 아웃 시작 전에 끈다 (점↔말풍선이 겹쳐서 교차되도록).
  void _setCollisionHiding(NMarker marker, bool hide) {
    try {
      marker.setIsHideCollidedMarkers(hide);
      marker.setIsHideCollidedCaptions(hide);
    } catch (_) {/* 네이티브에서 이미 제거된 경우 무시 */}
  }

  /// 모든 말풍선 즉시 삭제 + 타이머 정리 (전체 재렌더/화면 정리용).
  /// clusterableMarker 일괄 clear 에 안 걸리는 일반 NMarker 라 개별 삭제.
  Future<void> clear(NaverMapController? controller) async {
    cancelTimers();
    if (controller != null) {
      for (final id in _ids.toList()) {
        try {
          controller.deleteOverlay(
            NOverlayInfo(type: NOverlayType.marker, id: _overlayId(id)),
          );
        } catch (_) {}
      }
    }
    _ids.clear();
    _refs.clear();
    _removingIds.clear();
    _alpha.clear();
  }

  /// 진행 중인 페이드 타이머만 취소 (State.dispose 용).
  void cancelTimers() {
    for (final t in _fadeTimers.values) {
      t.cancel();
    }
    _fadeTimers.clear();
  }
}
