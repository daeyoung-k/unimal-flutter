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
  final BoardApiService _boardApiService = BoardApiService();
  BoardPost? _boardPost;
  bool _isLoading = true;

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
    super.dispose();
  }

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;

    // 키보드 내리기
    FocusScope.of(context).unfocus();

    // TODO: 실제 댓글 작성 API 호출 필요
    _commentController.clear();
    
    // 댓글 추가 후 게시글 다시 로드하여 최신 댓글 반영
    _loadBoardDetail();
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
        'id': int.tryParse(reply.id) ?? 0,
        'author': reply.nickname,
        'content': reply.comment,
        'profileImageUrl': _boardPost?.profileImage ?? 'https://via.placeholder.com/150',
        'createdAt': createdAt,
        'isOwner': reply.isOwner,
      };
    }).toList();
  }

  void _deleteComment(int commentId) {
    // TODO: 실제 댓글 삭제 API 호출 필요
    // 삭제 후 게시글 다시 로드
    _loadBoardDetail();
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중일 때 로딩 인디케이터 표시
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF4D91FF),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => Get.back(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF4D91FF),
      // 키보드가 올라올 때 레이아웃 자동 조정
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => Get.back(),
        ),
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 댓글 입력 영역 (키보드가 올라올 때 함께 올라감)
            CommentInput(controller: _commentController, onSend: _addComment),
          ],
        ),
      ),
    );
  }
}
