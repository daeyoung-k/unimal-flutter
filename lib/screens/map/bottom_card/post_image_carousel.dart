import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:unimal/service/board/model/file_info.dart';

/// Horizontal carousel of post images. Uses [ClampingScrollPhysics] so it
/// does NOT compete with the parent's vertical drag gesture (no overscroll
/// transferred to ancestors).
class PostImageCarousel extends StatefulWidget {
  final List<FileInfo> images;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;

  const PostImageCarousel({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.onIndexChanged,
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
    // 게시글 전환 시 부모가 initialIndex를 0으로 줄 수 있으므로 동기화
    if (widget.initialIndex != _current && _controller.hasClients) {
      _current = widget.initialIndex.clamp(0, widget.images.isEmpty ? 0 : widget.images.length - 1);
      _controller.jumpToPage(_current);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFF1F3F5),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 48, color: Color(0xFFBDBDBD)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return AspectRatio(aspectRatio: 1, child: _placeholder());
    }

    final total = widget.images.length;
    return AspectRatio(
      aspectRatio: 1,
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
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
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
                  color: const Color(0xCC1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_current + 1} / $total',
                  style: const TextStyle(
                    color: Colors.white,
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
                      color: active ? const Color(0xFF4D91FF) : const Color(0x66FFFFFF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
