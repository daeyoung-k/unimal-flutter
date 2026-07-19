import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/theme/app_colors.dart';
import 'package:unimal/utils/display_title.dart';

/// 스트립용 100×128 카드. 이미지 / 텍스트 분기 (figma node 125:8 기준).
class StoryThumbnailCard extends StatelessWidget {
  final BoardPost post;
  final VoidCallback onTap;

  const StoryThumbnailCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasImage = post.fileInfoList.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 100,
          height: 128,
          child: hasImage
              ? _ImageCard(post: post, colors: colors)
              : _TextCard(post: post, colors: colors),
        ),
      ),
    );
  }
}

/// 이미지 게시글 카드 — API 이미지 배경 + 하단 스크림 + place 아이콘 + 제목·♥.
class _ImageCard extends StatelessWidget {
  final BoardPost post;
  final AppColors colors;
  const _ImageCard({required this.post, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: post.fileInfoList.first.fileUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: colors.surfaceVariant),
          errorWidget: (_, __, ___) => Container(
            color: colors.primaryWash,
            child: Icon(Icons.image_not_supported_outlined,
                color: colors.primary, size: 24),
          ),
        ),
        // 가독성용 하단 스크림
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xCC000000), Colors.transparent],
              stops: [0.0, 0.6],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: Colors.white),
              _TitleAndLike(
                title: displayTitle(post.title, post.content),
                likeCount: post.likeCount,
                titleColor: Colors.white,
                likeColor: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 텍스트 게시글 카드 — 연한 배경 + sticky note 아이콘 + 본문 발췌 + 제목·♥.
class _TextCard extends StatelessWidget {
  final BoardPost post;
  final AppColors colors;
  const _TextCard({required this.post, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F8),
        border: Border.all(color: const Color(0xFFE1E7F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  size: 16, color: colors.primaryStrong),
              const SizedBox(height: 6),
              Text(
                post.content.trim(),
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  fontFamily: 'Pretendard',
                  color: Color(0xFF4A4A4F),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          _TitleAndLike(
            title: displayTitle(post.title, post.content),
            likeCount: post.likeCount,
            titleColor: const Color(0xFF8A8A8E),
            likeColor: const Color(0xFF8A8A8E),
          ),
        ],
      ),
    );
  }
}

class _TitleAndLike extends StatelessWidget {
  final String title;
  final int likeCount;
  final Color titleColor;
  final Color likeColor;
  const _TitleAndLike({
    required this.title,
    required this.likeCount,
    required this.titleColor,
    required this.likeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFamily: 'Pretendard',
            color: titleColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '♥ $likeCount',
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'Pretendard',
            color: likeColor,
          ),
        ),
      ],
    );
  }
}
