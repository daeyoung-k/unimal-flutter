import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/utils/time_utils.dart';

class BoardCard extends StatefulWidget {
  final BoardPost boardPost;

  const BoardCard({super.key, required this.boardPost});

  @override
  State<BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<BoardCard> {
  static const Color _primary = Color(0xFF7AB3FF);

  final BoardApiService _boardApiService = BoardApiService();
  final PageController _pageController = PageController();

  int _currentPage = 0;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLikeLoading = false;

  final GlobalKey _menuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.boardPost.isLike;
    _likeCount = widget.boardPost.likeCount;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToDetail() {
    Get.toNamed(
      '/detail-board',
      parameters: {'id': widget.boardPost.boardId},
      arguments: {'boardPost': widget.boardPost},
    );
  }

  Future<void> _toggleLike() async {
    if (_isLikeLoading) return;
    final prevLiked = _isLiked;
    final prevCount = _likeCount;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
      _isLikeLoading = true;
    });
    try {
      final likeInfo =
          await _boardApiService.requestLike(widget.boardPost.boardId);
      if (likeInfo != null && mounted) {
        setState(() {
          _isLiked = likeInfo.isLike;
          if (likeInfo.likeCount != null) _likeCount = likeInfo.likeCount!;
          _isLikeLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = prevLiked;
          _likeCount = prevCount;
          _isLikeLoading = false;
        });
      }
    }
  }

  void _showMenu() {
    if (!widget.boardPost.isOwner) return;
    final renderBox =
        _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(
            renderBox.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Colors.white,
      items: [
        PopupMenuItem(
          value: 'edit',
          height: 44,
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 16, color: Colors.grey[700]),
            const SizedBox(width: 10),
            Text('수정',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500)),
          ]),
        ),
        const PopupMenuItem(
          value: 'delete',
          height: 44,
          child: Row(children: [
            Icon(Icons.delete_outline, size: 16, color: Color(0xFFE53935)),
            SizedBox(width: 10),
            Text('삭제',
                style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFE53935),
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        Get.toNamed('/edit-board', arguments: widget.boardPost);
      } else if (value == 'delete') {
        _confirmDelete();
      }
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await Get.dialog<bool>(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('게시글 삭제',
          style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 16)),
      content: const Text('게시글을 삭제하면 복구할 수 없어요.\n정말 삭제할까요?',
          style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: Text('취소',
              style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500)),
        ),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: const Text('삭제',
              style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ));
    if (confirmed != true) return;
    final success =
        await _boardApiService.deleteBoard(widget.boardPost.boardId);
    if (success) {
      Get.offAllNamed('/board');
    }
  }

  Widget _buildAvatar() {
    final letter = widget.boardPost.nickname.isNotEmpty
        ? widget.boardPost.nickname[0]
        : '?';
    final url = widget.boardPost.profileImage;
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[200],
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (error, stackTrace) {
        },
        child: null,
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF7AB3FF), Color(0xFF3578E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(letter,
            style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.boardPost.fileInfoList
        .map((e) => e.fileUrl)
        .toList();

    return GestureDetector(
      onTap: _goToDetail,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7AB3FF).withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.boardPost.nickname,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                widget.boardPost.streetName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                    fontFamily: 'Pretendard'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.boardPost.isOwner)
                    GestureDetector(
                      key: _menuKey,
                      onTap: _showMenu,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.more_vert,
                            size: 20, color: Color(0xFF7AB3FF)),
                      ),
                    ),
                ],
              ),
            ),

            // 이미지 영역
            if (images.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Container(
                  height: 220,
                  color: const Color(0xFF1A1A2E),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (i) =>
                              setState(() => _currentPage = i),
                          itemBuilder: (context, index) {
                            return CachedNetworkImage(
                              imageUrl: images[index],
                              fit: BoxFit.contain,
                              width: double.infinity,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[100],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF7AB3FF),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[100],
                                child: const Center(
                                    child: Icon(Icons.broken_image_outlined,
                                        color: Colors.grey, size: 40)),
                              ),
                              imageBuilder: (context, imageProvider) =>
                                  Image(image: imageProvider, fit: BoxFit.contain, width: double.infinity),
                            );
                          },
                        ),
                      ),
                      if (images.length > 1)
                        Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              images.length,
                              (i) => Container(
                                width: i == _currentPage ? 16 : 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: i == _currentPage
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // 내용 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.boardPost.title.isNotEmpty)
                    Text(
                      widget.boardPost.title,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  if (widget.boardPost.title.isNotEmpty)
                    const SizedBox(height: 4),
                  Text(
                    widget.boardPost.content,
                    maxLines: images.isNotEmpty ? 2 : 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // 액션 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            key: ValueKey(_isLiked),
                            color: _isLiked ? Colors.red : Colors.grey[400],
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _likeCount.toString(),
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color:
                                _isLiked ? Colors.red : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 17, color: Colors.grey[400]),
                      const SizedBox(width: 5),
                      Text(
                        widget.boardPost.replyCount.toString(),
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        TimeUtils.getRelativeTime(
                            widget.boardPost.createdAt),
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
