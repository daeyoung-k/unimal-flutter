import 'package:flutter/material.dart';
import 'package:unimal/screens/add/share_card_sheet.dart';
import 'package:unimal/screens/map/bottom_card/map_card_expanded_content.dart';
import 'package:unimal/screens/map/bottom_card/post_image_carousel.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/map/models/map_post.dart';
import 'package:unimal/theme/app_colors.dart';

/// boardId를 받아 상세+댓글을 DraggableScrollableSheet로 표시.
/// 스트립/목록에서 onTap 시 showPostDetailSheet()로 호출.
Future<void> showPostDetailSheet(BuildContext context, String boardId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PostDetailSheet(boardId: boardId),
  );
}

class _PostDetailSheet extends StatefulWidget {
  final String boardId;
  const _PostDetailSheet({required this.boardId});

  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
  final _boardApi = BoardApiService();
  BoardPost? _detail;
  bool _isLoading = true;
  bool _isLiked = false;
  int? _likeCountOverride;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await _boardApi.getBoardDetail(widget.boardId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _isLiked = detail.isLike;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 별도 수정 화면 대신, 공유하기 시트를 "수정 모드"로 띄운다. (지도 카드와 동일)
  Future<void> _openEditSheet() async {
    if (_detail == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareCardSheet(editPost: _detail),
    );
    // 수정/삭제 성공 시 상세 시트를 닫는다(목록은 닫힌 뒤 재조회).
    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _onLikeTap() async {
    final result = await _boardApi.requestLike(widget.boardId);
    if (result != null && mounted) {
      setState(() {
        _isLiked = result.isLike;
        _likeCountOverride = result.likeCount;
      });
    }
  }

  /// 지도 카드 확장 화면과 동일하게 이미지 게시물이면 본문 위에 캐러셀을 얹는다.
  Widget _buildLoadedContent(BoardPost detail) {
    final post = _boardPostToMapPost(detail);
    return Column(
      children: [
        if (post.fileInfoList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PostImageCarousel(
                images: post.fileInfoList,
                initialIndex: _imageIndex,
                onIndexChanged: (i) => _imageIndex = i,
              ),
            ),
          ),
        Expanded(
          child: MapCardExpandedContent(
            post: post,
            detail: detail,
            isLoading: false,
            isLiked: _isLiked,
            likeCountOverride: _likeCountOverride,
            onLikeTap: _onLikeTap,
            onRefreshDetail: _loadDetail,
            onEditTap: detail.isOwner ? _openEditSheet : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colors.primaryStrong,
                          strokeWidth: 2,
                        ),
                      )
                    : _detail == null
                        ? Center(
                            child: Text(
                              '게시글을 불러오지 못했어요',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                color: colors.textTertiary,
                              ),
                            ),
                          )
                        : _buildLoadedContent(_detail!),
              ),
            ],
          ),
        );
      },
    );
  }
}

MapPost _boardPostToMapPost(BoardPost bp) => MapPost(
      id: bp.boardId,
      nickname: bp.nickname,
      profileImage: bp.profileImage.isNotEmpty ? bp.profileImage : null,
      title: bp.title,
      content: bp.content,
      streetName: bp.streetName,
      latitude: bp.latitude ?? 0.0,
      longitude: bp.longitude ?? 0.0,
      createdAt: bp.createdAt,
      fileInfoList: bp.fileInfoList,
      likeCount: bp.likeCount,
      replyCount: bp.replyCount,
      score: 0.0,
      isOwner: bp.isOwner,
      isLike: bp.isLike,
    );
