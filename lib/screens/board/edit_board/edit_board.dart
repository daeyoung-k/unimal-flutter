import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/board/model/file_info.dart';

class EditBoardScreen extends StatefulWidget {
  const EditBoardScreen({super.key});

  @override
  State<EditBoardScreen> createState() => _EditBoardScreenState();
}

class _EditBoardScreenState extends State<EditBoardScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF7AB3FF);
  static const Color _primaryDark = Color(0xFF3578E5);

  late AnimationController _ctrl;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;
  late Animation<Offset> _card1Slide;
  late Animation<double> _card1Fade;
  late Animation<Offset> _card2Slide;
  late Animation<double> _card2Fade;
  late Animation<Offset> _card3Slide;
  late Animation<double> _card3Fade;
  late Animation<double> _btnFade;

  final BoardApiService _boardApiService = BoardApiService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  late BoardPost _boardPost;
  bool _isShow = true;
  bool _isSaving = false;

  final List<String> _removedFileIds = [];
  final List<File> _newImages = [];

  @override
  void initState() {
    super.initState();
    _boardPost = Get.arguments as BoardPost;
    _titleController.text = _boardPost.title;
    _contentController.text = _boardPost.content;
    _isShow = _boardPost.show == 'PUBLIC';

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _headerSlide = Tween(begin: const Offset(0, -0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _headerFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)),
    );
    _card1Slide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.5, curve: Curves.easeOut)),
    );
    _card1Fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.45, curve: Curves.easeOut)),
    );
    _card2Slide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.65, curve: Curves.easeOut)),
    );
    _card2Fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
    );
    _card3Slide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 0.8, curve: Curves.easeOut)),
    );
    _card3Fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 0.75, curve: Curves.easeOut)),
    );
    _btnFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.65, 1.0, curve: Curves.easeOut)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool _canSave() {
    return _titleController.text.trim().isNotEmpty &&
        _contentController.text.trim().isNotEmpty;
  }

  List<FileInfo> get _remainingFiles =>
      _boardPost.fileInfoList.where((f) => !_removedFileIds.contains(f.fileId)).toList();

  Future<void> _pickImages() async {
    final picked = await _imagePicker.pickMultiImage();
    if (picked.isEmpty) return;
    setState(() {
      _newImages.addAll(picked.map((e) => File(e.path)));
    });
  }

  void _removeExistingImage(String fileId) {
    setState(() => _removedFileIds.add(fileId));
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '게시글 삭제',
          style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: const Text(
          '게시글을 삭제하면 복구할 수 없어요.\n정말 삭제할까요?',
          style: TextStyle(fontFamily: 'Pretendard', fontSize: 14, color: Color(0xFF666666), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              '취소',
              style: TextStyle(fontFamily: 'Pretendard', color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              '삭제',
              style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFFE53935), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _boardApiService.deleteBoard(_boardPost.boardId);
    if (success) {
      Get.offAllNamed('/board');
    } else {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('삭제 실패', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16)),
          content: const Text(
            '게시글 삭제에 실패했습니다.\n잠시 후 다시 시도해주세요.',
            style: TextStyle(fontFamily: 'Pretendard', fontSize: 14, color: Color(0xFF666666)),
          ),
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

  Future<void> _savePost() async {
    if (!_canSave() || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (_removedFileIds.isNotEmpty) {
        await _boardApiService.deleteBoardFiles(_boardPost.boardId, _removedFileIds);
      }
      if (_newImages.isNotEmpty) {
        await _boardApiService.uploadBoardFiles(_boardPost.boardId, _newImages);
      }

      final success = await _boardApiService.updateBoard(
        boardId: _boardPost.boardId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        isShow: _isShow,
      );

      if (success) {
        Get.offNamed('/detail-board', parameters: {'id': _boardPost.boardId});
      } else {
        Get.dialog(
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('수정 실패', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16)),
            content: const Text(
              '게시글 수정에 실패했습니다.\n잠시 후 다시 시도해주세요.',
              style: TextStyle(fontFamily: 'Pretendard', fontSize: 14, color: Color(0xFF666666)),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('확인', style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFF4D91FF), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_primaryDark, _primary, Color(0xFFA8CCFF)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 헤더
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                            onPressed: () => Get.back(),
                          ),
                          const Expanded(
                            child: Text(
                              '수정하기',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                            onPressed: _confirmDelete,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 본문
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 이미지 섹션 (card1)
                        FadeTransition(
                          opacity: _card1Fade,
                          child: SlideTransition(
                            position: _card1Slide,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '첫 번째 사진이 지도 위 스토리의 대표 이미지로 표시돼요.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontFamily: 'Pretendard',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ..._remainingFiles.map((file) => _buildExistingImageItem(file)),
                                      ..._newImages.asMap().entries.map((e) => _buildNewImageItem(e.key, e.value)),
                                      if (_remainingFiles.length + _newImages.length < 5)
                                        GestureDetector(
                                          onTap: _pickImages,
                                          child: Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.95),
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.1),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: _primary.withValues(alpha: 0.12),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.add_rounded, color: _primary, size: 22),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_remainingFiles.length + _newImages.length}/5',
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 11,
                                                    fontFamily: 'Pretendard',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),

                        // 제목 + 내용 카드 (card2)
                        FadeTransition(
                          opacity: _card2Fade,
                          child: SlideTransition(
                            position: _card2Slide,
                            child: Column(
                              children: [
                                _buildCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '제목',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _titleController,
                                        onChanged: (_) => setState(() {}),
                                        style: const TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 16,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: '제목을 입력하세요.',
                                          hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Pretendard'),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '내용',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _contentController,
                                        onChanged: (_) => setState(() {}),
                                        maxLines: 5,
                                        style: const TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 15,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: '내용을 입력하세요.',
                                          hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Pretendard'),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),

                        // 지도 노출 토글 (card3)
                        FadeTransition(
                          opacity: _card3Fade,
                          child: SlideTransition(
                            position: _card3Slide,
                            child: _buildCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '지도 노출',
                                          style: TextStyle(
                                            color: Color(0xFF1A1A2E),
                                            fontFamily: 'Pretendard',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          '켜두면 내 스토리가 지도에 핀으로 표시돼요.',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontFamily: 'Pretendard',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _isShow,
                                    onChanged: (v) => setState(() => _isShow = v),
                                    activeThumbColor: _primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 저장 버튼
                        FadeTransition(
                          opacity: _btnFade,
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: (_canSave() && !_isSaving) ? _savePost : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _canSave() && !_isSaving
                                    ? Colors.white.withValues(alpha: 0.95)
                                    : Colors.white.withValues(alpha: 0.4),
                                foregroundColor: _primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: _canSave() && !_isSaving ? 6 : 0,
                                shadowColor: Colors.black.withValues(alpha: 0.15),
                              ),
                              child: _isSaving
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(_primary),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          '저장 중...',
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: _primary,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: _canSave() ? _primary : Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '수정 완료',
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: _canSave() ? _primary : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildExistingImageItem(FileInfo file) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              file.fileUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: Colors.white.withValues(alpha: 0.2),
                child: const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeExistingImage(file.fileId),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B6B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewImageItem(int index, File file) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeNewImage(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B6B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
