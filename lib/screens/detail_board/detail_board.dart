import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/screens/detail_board/comment/comment_input.dart';
import 'package:unimal/screens/detail_board/comment/comment_section.dart';
import 'package:unimal/screens/detail_board/detail_card/detail_board_card.dart';
import 'package:unimal/screens/widget/alert/custom_alert.dart';
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
  final List<Map<String, dynamic>> _comments = [];
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
                "/board"
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
              "/board"
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

    setState(() {
      _comments.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'author': '나',
        'content': _commentController.text.trim(),
        'profileImageUrl': 'https://via.placeholder.com/150',
        'createdAt': DateTime.now(),
      });
      _commentController.clear();
    });

    // 댓글 추가 후 스크롤을 맨 아래로
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
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
                      DetailBoardCard(boardPost: _boardPost ?? BoardPost(boardId: '', profileImage: '', email: '', nickname: '', title: '', content: '', streetName: '', show: '', mapShow: '', fileInfoList: [], createdAt: '', likeCount: 0, replyCount: 0, reply: [], isLike: false, isOwner: false)),
                      
                    ],
                  ),
                ),
              ),
            ),
            // 댓글 입력 영역 (키보드가 올라올 때 함께 올라감)
            CommentInput(
              controller: _commentController,
              onSend: _addComment,
            ),
          ],
        ),
      ),
    );
  }
}



