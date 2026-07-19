import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:unimal/service/board/model/file_info.dart';
import 'package:unimal/theme/app_colors.dart';

/// Horizontal carousel of post images. Uses [ClampingScrollPhysics] so it
/// does NOT compete with the parent's vertical drag gesture (no overscroll
/// transferred to ancestors).
class PostImageCarousel extends StatefulWidget {
  final List<FileInfo> images;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;
  final double height;

  const PostImageCarousel({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.height = 220,
  });

  @override
  State<PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<PostImageCarousel> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.images.isEmpty ? 0 : widget.images.length - 1);
    _controller = PageController(initialPage: _current);
  }

  @override
  void didUpdateWidget(covariant PostImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 게시글 전환(images 리스트 교체) 또는 부모가 새 initialIndex를 요구할 때 동기화.
    // images만 비교하면 충분 — 새 게시글이면 거의 항상 다른 List 인스턴스.
    final imagesChanged = oldWidget.images != widget.images;
    final indexChanged = widget.initialIndex != _current;
    if (!imagesChanged && !indexChanged) return;

    _current = widget.initialIndex.clamp(
      0,
      widget.images.isEmpty ? 0 : widget.images.length - 1,
    );
    if (_controller.hasClients) {
      _controller.jumpToPage(_current);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _placeholder(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      color: colors.surfaceVariant,
      child: Center(
        child: Icon(Icons.image_outlined, size: 48, color: colors.textMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (widget.images.isEmpty) {
      return SizedBox(height: widget.height, child: _placeholder(context));
    }

    final total = widget.images.length;
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            physics: const ClampingScrollPhysics(),
            itemCount: total,
            onPageChanged: (i) {
              setState(() => _current = i);
              widget.onIndexChanged?.call(i);
            },
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: widget.images[index].fileUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _ImageSkeleton(),
                errorWidget: (_, __, ___) => _placeholder(context),
              );
            },
          ),
          // 우상단 N / total 뱃지 (단일 이미지면 숨김)
          if (total > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  // 다크 오버레이 — textPrimary 80% (light: 진한 네이비, dark: 옅은)
                  color: colors.textPrimary.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_current + 1} / $total',
                  style: TextStyle(
                    color: colors.surface,
                    fontSize: 12,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          // 하단 도트 인디케이터 (단일 이미지면 숨김)
          if (total > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final active = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? colors.primaryStrong
                          : colors.surface.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          // 좌우 탭 존 — 탭으로 이미지 전환, 스와이프는 PageView로 통과
          if (total > 1) ...[
            // 왼쪽 탭 존
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 44,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_current > 0) {
                    _controller.previousPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
            // 오른쪽 탭 존
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 44,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_current < total - 1) {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 이미지 로딩 중 표시하는 시머 스켈레톤.
/// 좌→우로 밝은 띠가 흐르며 부드럽게 로딩을 알린다(이미지 없음 이모지 대체).
class _ImageSkeleton extends StatefulWidget {
  const _ImageSkeleton();

  @override
  State<_ImageSkeleton> createState() => _ImageSkeletonState();
}

class _ImageSkeletonState extends State<_ImageSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final base = colors.surfaceVariant;
    final highlight = colors.surface;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // -1(좌측 밖) → 2(우측 밖)로 밝은 띠가 흐른다.
        final dx = -1.0 + 3.0 * _ctrl.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(dx - 0.5, 0),
              end: Alignment(dx + 0.5, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
