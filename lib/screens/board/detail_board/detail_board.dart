import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/screens/board/detail_board/comment/comment_input.dart';
import 'package:unimal/screens/board/detail_board/comment/comment_section.dart';
import 'package:unimal/screens/board/detail_board/detail_card/detail_board_card.dart';
import 'package:unimal/utils/custom_alert.dart';
import 'package:unimal/service/board/board_api_service.dart';

class DetailBoardScreen extends StatefulWidget {
  const DetailBoardScreen({super.key});

  @override
  State<DetailBoardScreen> createState() => _DetailBoardScreenState();
}

class _DetailBoardScreenState extends State<DetailBoardScreen> {
  var logger = Logger();
  final CustomAlert _customAlert = CustomAlert();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();
  final BoardApiService _boardApiService = BoardApiService();
  BoardPost? _boardPost;
  bool _isLoading = true;

  String? _replyToId;
  String? _replyToNickname;

  void _setReplyTo(String replyId, String nickname) {
    setState(() {
      _replyToId = replyId;
      _replyToNickname = nickname;
    });
    _commentFocusNode.requestFocus();
    // 입력창이 보이도록 스크롤을 맨 아래로
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearReplyTo() {
    setState(() {
      _replyToId = null;
      _replyToNickname = null;
    });
  }

  @override
  void initState() {
    super.initState();
    // initState는 동기 메서드이므로 await 없이 비동기 메서드 호출
    // 비동기 작업은 메서드 내부에서 처리하고 setState로 UI 업데이트
    _loadBoardDetail();
  }

  // 페이지 진입 시마다 기존 파라미터를 초기화하고 새롭게 로드하는 메서드
  Future<void> _loadBoardDetail() async {
    try {
      // Get.parameters에서 현재 파라미터 가져오기 (항상 최신 값)
      final String? id = Get.parameters['id'];

      // 파라미터가 없거나 비어있으면 에러 처리 및 경고창 표시
      if (id == null || id.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          // build 완료 후 경고창 표시 (build 중 다이얼로그 표시 방지)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _customAlert.showTextAlertAndNavigate(
                "게시글 없음",
                "게시글이 존재하지 않습니다.",
                "/board",
              );
            }
          });
        }
        return;
      }

      // 매번 새로 로드하므로 중복 체크 없이 바로 로드
      final boardPost = await _boardApiService.getBoardDetail(id);
      // UI 업데이트를 위해 setState 호출
      if (mounted) {
        setState(() {
          _boardPost = boardPost;
          _isLoading = false;
        });
      }
    } catch (e) {
      // 에러 발생 시 로그 출력 및 경고창 표시
      logger.e('게시글 상세 조회 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // build 완료 후 경고창 표시 (build 중 다이얼로그 표시 방지)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _customAlert.showTextAlertAndNavigate(
              "오류",
              "게시글을 불러오는데 실패했습니다.\n잠시 후 다시 시도해주세요.",
              "/board",
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  bool _isSendingComment = false;

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSendingComment || _boardPost == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSendingComment = true);

    final success = await _boardApiService.createReply(
      _boardPost!.boardId,
      text,
      replyId: _replyToId,
    );

    if (mounted) {
      setState(() => _isSendingComment = false);
      if (success) {
        _commentController.clear();
        _clearReplyTo();
        _loadBoardDetail();
      }
    }
  }

  // ReplyInfo 리스트를 CommentSection이 사용할 수 있는 형태로 변환
  List<Map<String, dynamic>> _convertRepliesToComments() {
    if (_boardPost == null || _boardPost!.reply.isEmpty) {
      return [];
    }

    return _boardPost!.reply
        .where((reply) => !reply.isDel) // 삭제된 댓글 제외
        .map((reply) {
      // createdAt 문자열을 DateTime으로 변환
      DateTime createdAt;
      try {
        createdAt = DateTime.parse(reply.createdAt);
      } catch (e) {
        createdAt = DateTime.now();
      }

      return {
        'id': reply.id,
        'parentId': reply.replyId ?? '',
        'author': reply.nickname,
        'content': reply.comment,
        'profileImageUrl': _boardPost?.profileImage ?? 'https://via.placeholder.com/150',
        'createdAt': createdAt,
        'isOwner': reply.isOwner,
      };
    }).toList();
  }

  Future<void> _deleteComment(String replyId) async {
    if (_boardPost == null) return;
    final success = await _boardApiService.deleteReply(_boardPost!.boardId, replyId);
    if (success && mounted) _loadBoardDetail();
  }

  Future<void> _editComment(String replyId, String currentContent) async {
    if (_boardPost == null) return;
    final controller = TextEditingController(text: currentContent);

    final newContent = await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('댓글 수정', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('취소', style: TextStyle(fontFamily: 'Pretendard', color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => Get.back(result: controller.text.trim()),
            child: const Text('수정', style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFF4D91FF), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (newContent == null || newContent.isEmpty) return;

    final success = await _boardApiService.updateReply(_boardPost!.boardId, replyId, newContent);
    if (success && mounted) _loadBoardDetail();
  }

  final GlobalKey _menuButtonKey = GlobalKey();

  void _showPostMenu() {
    final renderBox = _menuButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero), ancestor: overlay),
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
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 10),
              Text('수정', style: TextStyle(fontSize: 14, color: Colors.grey[800], fontFamily: 'Pretendard', fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 44,
          child: const Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Color(0xFFE53935)),
              SizedBox(width: 10),
              Text('삭제', style: TextStyle(fontSize: 14, color: Color(0xFFE53935), fontFamily: 'Pretendard', fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        Get.toNamed('/edit-board', arguments: _boardPost);
      } else if (value == 'delete') {
        _confirmDelete();
      }
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('게시글 삭제', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text('게시글을 삭제하면 복구할 수 없어요.\n정말 삭제할까요?', style: TextStyle(fontFamily: 'Pretendard', fontSize: 14, color: Color(0xFF666666), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('취소', style: TextStyle(fontFamily: 'Pretendard', color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('삭제', style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _boardApiService.deleteBoard(_boardPost!.boardId);
    if (success) {
      Get.offAllNamed('/board');
    } else {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('삭제 실패', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16)),
          content: const Text('게시글 삭제에 실패했습니다.\n잠시 후 다시 시도해주세요.', style: TextStyle(fontFamily: 'Pretendard', fontSize: 14, color: Color(0xFF666666))),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('확인', style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFF4D91FF), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    void goToBoard() => Get.offAllNamed('/board');

    // 로딩 중일 때 로딩 인디케이터 표시
    if (_isLoading) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) { if (!didPop) goToBoard(); },
        child: Scaffold(
          backgroundColor: const Color(0xFF4D91FF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: goToBoard,
            ),
          ),
          body: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) goToBoard(); },
      child: Scaffold(
      backgroundColor: const Color(0xFF4D91FF),
      // 키보드가 올라올 때 레이아웃 자동 조정
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: goToBoard,
        ),
        actions: [
          if (_boardPost?.isOwner == true)
            IconButton(
              key: _menuButtonKey,
              onPressed: _showPostMenu,
              icon: const Icon(Icons.more_horiz, color: Colors.white),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                  child: Column(
                    children: [
                      DetailBoardCard(
                        boardPost:
                            _boardPost ?? BoardPost(
                                            boardId: '',
                                            profileImage: '',
                                            email: '',
                                            nickname: '',
                                            title: '',
                                            content: '',
                                            streetName: '',
                                            show: '',
                                            mapShow: '',
                                            fileInfoList: [],
                                            createdAt: '',
                                            likeCount: 0,
                                            replyCount: 0,
                                            reply: [],
                                            isLike: false,
                                            isOwner: false,
                                          ),
                      ),
                      const SizedBox(height: 16),
                      // 서버에서 받아온 댓글 리스트 표시
                      CommentSection(
                        comments: _convertRepliesToComments(),
                        onDelete: _deleteComment,
                        onEdit: _editComment,
                        onReply: _setReplyTo,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 댓글 입력 영역 (키보드가 올라올 때 함께 올라감)
            CommentInput(
              controller: _commentController,
              focusNode: _commentFocusNode,
              onSend: _addComment,
              isLoading: _isSendingComment,
              replyToNickname: _replyToNickname,
              onCancelReply: _clearReplyTo,
            ),
          ],
        ),
      ),
    ));
  }
}
