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

class MapThumbnailStrip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    assert(currentGroupIndex >= 0 && currentGroupIndex < groups.length,
        'currentGroupIndex ($currentGroupIndex) out of range [0, ${groups.length})');
    final indices = stripVisibleIndices(groups.length, currentGroupIndex);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: indices.map((i) {
          final isActive = i == currentGroupIndex;
          final isTextPost = groups[i].isEmpty || groups[i].first.fileInfoList.isEmpty;
          final size = isActive ? 70.0 : 50.0;
          final opacity = () {
            final dist = (i - currentGroupIndex).abs();
            return dist == 0 ? 1.0 : dist == 1 ? 0.65 : 0.45;
          }();

          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedOpacity(
              opacity: opacity,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size,
                height: size,
                margin: EdgeInsets.symmetric(horizontal: isActive ? 4 : 3),
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
                          imageUrl: groups[i].first.fileInfoList.first.fileUrl,
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
          );
        }).toList(),
      ),
    );
  }
}
