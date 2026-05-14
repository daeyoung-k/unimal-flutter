import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:unimal/service/map/models/map_post.dart';

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

  const MapThumbnailStrip({
    super.key,
    required this.groups,
    required this.currentGroupIndex,
    required this.onTap,
  });

  @override
  State<MapThumbnailStrip> createState() => _MapThumbnailStripState();
}

class _MapThumbnailStripState extends State<MapThumbnailStrip> {
  // 한 칸 슬롯 너비 — 활성 썸네일(70)과 같은 70px.
  // 5칸 × 70 = 350px 이라 360px 이하 화면(iPhone SE 등)에서도 fit.
  static const _itemWidth = 70.0;

  double _dragAccum = 0;
  bool _isDragging = false;
  int? _visualIndex; // 드래그 중에만 사용되는 시각적 활성 인덱스

  int get _effectiveIndex => _visualIndex ?? widget.currentGroupIndex;

  void _onDragStart(DragStartDetails d) {
    setState(() {
      _isDragging = true;
      _dragAccum = 0;
      _visualIndex = widget.currentGroupIndex;
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    var newAccum = _dragAccum + d.delta.dx;
    var idx = _visualIndex ?? widget.currentGroupIndex;

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
  }

  void _onDragEnd(DragEndDetails d) {
    final finalIdx = _visualIndex ?? widget.currentGroupIndex;
    setState(() {
      _isDragging = false;
      _dragAccum = 0;
      _visualIndex = null;
    });
    // 드래그로 인덱스가 바뀐 경우에만 최종 그룹으로 commit (parent가 카메라 이동)
    if (finalIdx != widget.currentGroupIndex) {
      widget.onTap(finalIdx);
    }
  }

  void _onDragCancel() {
    setState(() {
      _isDragging = false;
      _dragAccum = 0;
      _visualIndex = null;
    });
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
      child: AnimatedContainer(
        duration: _isDragging
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(_dragAccum, 0, 0),
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: indices.map((i) {
          // 경계 패딩 슬롯 — 빈 공간만 차지
          if (i == null) return const SizedBox(width: _itemWidth);
          final isActive = i == activeIdx;
          final isTextPost = widget.groups[i].isEmpty || widget.groups[i].first.fileInfoList.isEmpty;
          final size = isActive ? 70.0 : 50.0;
          final opacity = () {
            final dist = (i - activeIdx).abs();
            return dist == 0 ? 1.0 : dist == 1 ? 0.65 : 0.45;
          }();

          return SizedBox(
            width: _itemWidth,
            child: Center(
              child: GestureDetector(
                onTap: () => widget.onTap(i),
                child: AnimatedOpacity(
                  opacity: opacity,
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 340),
                    curve: Curves.easeOutCubic,
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF4D91FF)
                        : isTextPost
                            ? const Color(0xFFFF9F43)
                            : const Color(0xFFBBBBBB),
                    width: isActive ? 2.0 : 1.5,
                  ),
                  boxShadow: isActive
                      ? [
                          const BoxShadow(
                            color: Color(0x444D91FF),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.5),
                  child: isTextPost
                      ? Container(
                          color: const Color(0xFFF5F5F5),
                          child: Center(
                            child: Text(
                              '💬',
                              style: TextStyle(fontSize: size * 0.45),
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: widget.groups[i].first.fileInfoList.first.fileUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const ColoredBox(
                            color: Color(0xFFF5F5F5),
                          ),
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: Color(0xFFF5F5F5),
                          ),
                        ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      ),
      ),
    );
  }
}
