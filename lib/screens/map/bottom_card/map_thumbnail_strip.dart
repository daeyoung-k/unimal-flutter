import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:unimal/service/map/models/map_post.dart';
import 'package:unimal/theme/app_colors.dart';

/// 현재 그룹 기준으로 표시할 인덱스 목록 반환 (최대 2+현재+2).
/// 범위 초과 인덱스는 포함하지 않으며, 별도 오버플로 표시 없음.
List<int> stripVisibleIndices(int groupCount, int currentIndex) {
  final result = <int>[];
  for (int offset = -2; offset <= 2; offset++) {
    final idx = currentIndex + offset;
    if (idx >= 0 && idx < groupCount) result.add(idx);
  }
  return result;
}

class MapThumbnailStrip extends StatefulWidget {
  final List<List<MapPost>> groups;
  final int currentGroupIndex;
  final ValueChanged<int> onTap;

  /// 드래그 중 시각적 활성 인덱스가 바뀔 때 즉시 호출.
  /// (parent가 카드 본문을 동기화하도록)
  final ValueChanged<int>? onVisualIndexChange;

  const MapThumbnailStrip({
    super.key,
    required this.groups,
    required this.currentGroupIndex,
    required this.onTap,
    this.onVisualIndexChange,
  });

  @override
  State<MapThumbnailStrip> createState() => _MapThumbnailStripState();
}

class _MapThumbnailStripState extends State<MapThumbnailStrip>
    with SingleTickerProviderStateMixin {
  // 한 칸 슬롯 너비 — 활성 썸네일(70)과 같은 70px.
  // 5칸 × 70 = 350px 이라 360px 이하 화면(iPhone SE 등)에서도 fit.
  static const _itemWidth = 70.0;

  // Active 강조 데드존 (슬롯 너비의 비율).
  // 이 범위 안에서는 fully active로 표시 + 손 떼면 그 슬롯으로 commit.
  static const _activeDeadzone = 0.6;

  double _dragAccum = 0;
  int? _visualIndex; // 드래그 중에만 사용되는 시각적 활성 인덱스
  int? _dragStartIdx; // 드래그 시작 시점의 인덱스 — commit 판단용

  // Spring 시뮬레이션 컨트롤러 — 드래그/탭 종료 후 _dragAccum을 0으로 감쇠.
  // unbounded 컨트롤러: value가 _dragAccum과 직접 매핑됨.
  late final AnimationController _snapController;

  // Spring 파라미터 — 인스타그램/iOS 앨범 같은 쫀득한 감쇠 느낌
  // damping ratio ≈ 0.85 (약간의 잔진동, 빠른 정착)
  static final SpringDescription _spring = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 22.0,
  );

  int get _effectiveIndex => _visualIndex ?? widget.currentGroupIndex;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() => _dragAccum = _snapController.value);
      });
  }

  /// _dragAccum을 0으로 Spring 시뮬레이션. velocity가 있으면 관성 보존.
  void _snapToZero({double velocity = 0}) {
    _snapController.stop();
    _snapController.value = _dragAccum;
    final simulation = SpringSimulation(_spring, _dragAccum, 0, velocity);
    _snapController.animateWith(simulation);
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    // 진행 중인 spring/관성 애니메이션 즉시 중지 (충돌 방지)
    _snapController.stop();
    _dragStartIdx = widget.currentGroupIndex;
    setState(() {
      _dragAccum = 0;
      _visualIndex = widget.currentGroupIndex;
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    var newAccum = _dragAccum + d.delta.dx;
    final prevIdx = _visualIndex ?? widget.currentGroupIndex;
    var idx = prevIdx;

    // 우로 드래그(newAccum > 0) → 이전 그룹으로 포커스 이동
    while (newAccum >= _itemWidth) {
      if (idx > 0) {
        idx--;
        newAccum -= _itemWidth;
      } else {
        newAccum = _itemWidth * 0.6; // 경계 저항감
        break;
      }
    }
    // 좌로 드래그(newAccum < 0) → 다음 그룹으로 포커스 이동
    while (newAccum <= -_itemWidth) {
      if (idx < widget.groups.length - 1) {
        idx++;
        newAccum += _itemWidth;
      } else {
        newAccum = -_itemWidth * 0.6;
        break;
      }
    }

    setState(() {
      _dragAccum = newAccum;
      _visualIndex = idx;
    });
    // 시각적 활성 인덱스가 바뀌면 parent에 알림 (카드 본문 즉시 갱신)
    if (idx != prevIdx) widget.onVisualIndexChange?.call(idx);
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0; // 픽셀/초 (좌=음수, 우=양수)
    var finalIdx = _visualIndex ?? widget.currentGroupIndex;

    // 관성을 고려한 "예상 정착 위치" — 거리만으로 부족한 짧고 빠른 플릭도 잡힘.
    // inertiaFactor가 클수록 velocity 영향 강함 (보통 0.1~0.25)
    const inertiaFactor = 0.18;
    final projectedOffset = _dragAccum + velocity * inertiaFactor;

    // projectedOffset이 active 데드존 넘었으면 인접 슬롯으로 commit
    if (projectedOffset.abs() > _itemWidth * _activeDeadzone) {
      final dir = projectedOffset < 0 ? 1 : -1;
      final candidate = finalIdx + dir;
      if (candidate >= 0 && candidate < widget.groups.length) {
        finalIdx = candidate;
      }
    }

    setState(() => _visualIndex = null);
    // spring은 velocity 0으로 (남은 관성 무시) → 어색한 튕김 없이 깔끔하게 정착
    _snapToZero();
    // 드래그 시작 시점 인덱스와 비교 — _previewGroup으로 nav가 이미 변경됐어도 commit 통지
    final startIdx = _dragStartIdx ?? widget.currentGroupIndex;
    _dragStartIdx = null;
    if (finalIdx != startIdx) {
      widget.onTap(finalIdx);
    }
  }

  void _onDragCancel() {
    _dragStartIdx = null;
    setState(() => _visualIndex = null);
    _snapToZero();
  }

  /// 슬롯 탭 — 새 인덱스로 변경하되, _dragAccum을 차이만큼 설정해서
  /// row가 시각적으로 이전 위치에서 새 위치로 spring으로 슬라이드.
  void _onSlotTap(int newIdx) {
    final oldIdx = _effectiveIndex;
    if (newIdx == oldIdx) return;
    _snapController.stop();
    setState(() {
      // 새 윈도우 기준으로 newIdx는 항상 slot 2(중앙). 시각적으로 이전 슬롯 위치
      // (newIdx - oldIdx) * itemWidth 만큼 떨어진 곳에서 출발하도록 보정.
      _dragAccum = (newIdx - oldIdx) * _itemWidth;
    });
    widget.onTap(newIdx);
    _snapToZero();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.currentGroupIndex >= 0 &&
            widget.currentGroupIndex < widget.groups.length,
        'currentGroupIndex (${widget.currentGroupIndex}) out of range [0, ${widget.groups.length})');
    final activeIdx = _effectiveIndex;
    // 항상 5칸 (좌2+활성+우2). 경계에서는 null로 패딩 → row 너비 일정 유지
    final List<int?> indices = [
      for (int offset = -2; offset <= 2; offset++)
        () {
          final i = activeIdx + offset;
          return (i >= 0 && i < widget.groups.length) ? i : null;
        }(),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: _onDragCancel,
      child: Transform.translate(
        offset: Offset(_dragAccum, 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(indices.length, (slotPos) {
              final i = indices[slotPos];
              // 경계 패딩 슬롯 — 빈 공간만 차지
              if (i == null) return const SizedBox(width: _itemWidth);
              return _buildSlot(i, slotPos);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildSlot(int i, int slotPos) {
    final isTextPost =
        widget.groups[i].isEmpty || widget.groups[i].first.fileInfoList.isEmpty;

    // 슬롯 중앙이 화면 중심에서 얼마나 떨어져 있는지 (드래그 보정 포함)
    final centerOffset = (slotPos - 2) * _itemWidth + _dragAccum;
    // 정규화: 0 = 중앙 슬롯, 1 = 한 칸 거리, 2 = 두 칸 거리
    final t = (centerOffset.abs() / _itemWidth).clamp(0.0, 2.0);

    // 거리 기반 연속 보간 (size, opacity는 부드럽게)
    final size = lerpDouble(70.0, 44.0, t / 2)!; // 중앙 70 → 끝 44
    final opacity = lerpDouble(1.0, 0.45, t / 2)!; // 중앙 1.0 → 끝 0.45

    // Active 강조 — 데드존 안에서 fully active, 그 후 선형 감소
    final activeness = t < _activeDeadzone
        ? 1.0
        : ((1.0 - t) / (1.0 - _activeDeadzone)).clamp(0.0, 1.0);

    final colors = AppColors.of(context);
    final borderColor = Color.lerp(
      isTextPost ? colors.accent : colors.borderStrong,
      colors.primaryStrong,
      activeness,
    )!;
    final borderWidth = lerpDouble(1.5, 2.0, activeness)!;

    return SizedBox(
      width: _itemWidth,
      child: Center(
        child: GestureDetector(
          onTap: () => _onSlotTap(i),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: activeness > 0.05
                    ? [
                        BoxShadow(
                          color: colors.primaryStrong
                              .withValues(alpha: 0.27 * activeness),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: isTextPost
                    ? Container(
                        color: colors.surfaceVariant,
                        child: Center(
                          child: Text(
                            '💬',
                            style: TextStyle(fontSize: size * 0.45),
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl:
                            widget.groups[i].first.fileInfoList.first.fileUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ColoredBox(
                          color: colors.surfaceVariant,
                        ),
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: colors.surfaceVariant,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
