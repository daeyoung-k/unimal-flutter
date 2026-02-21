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

class _EditBoardScreenState extends State<EditBoardScreen> {
  final BoardApiService _boardApiService = BoardApiService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  late BoardPost _boardPost;
  bool _isShow = true;
  bool _isSaving = false;

  // 기존 이미지 중 삭제할 fileId 목록
  final List<String> _removedFileIds = [];
  // 새로 추가한 이미지 파일 목록
  final List<File> _newImages = [];

  @override
  void initState() {
    super.initState();
    _boardPost = Get.arguments as BoardPost;
    _titleController.text = _boardPost.title;
    _contentController.text = _boardPost.content;
    _isShow = _boardPost.show == 'PUBLIC';
  }

  @override
  void dispose() {
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
    setState(() {
      _removedFileIds.add(fileId);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
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

    final success = await _boardApiService.deleteBoard(_boardPost.boardId);
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

  Future<void> _savePost() async {
    if (!_canSave() || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      // 1) 삭제할 이미지 제거
      if (_removedFileIds.isNotEmpty) {
        await _boardApiService.deleteBoardFiles(_boardPost.boardId, _removedFileIds);
      }

      // 2) 새 이미지 업로드
      if (_newImages.isNotEmpty) {
        await _boardApiService.uploadBoardFiles(_boardPost.boardId, _newImages);
      }

      // 3) 게시글 내용 수정
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
            content: const Text('게시글 수정에 실패했습니다.\n잠시 후 다시 시도해주세요.', style: TextStyle(fontFamily: 'Pretendard', fontSize: 14, color: Color(0xFF666666))),
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
    final remaining = _remainingFiles;
    final hasImages = remaining.isNotEmpty || _newImages.isNotEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF4D91FF),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: const Text(
            '수정하기',
            style: TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'Pretendard', fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: '게시글 삭제',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이미지 영역
                  if (hasImages || true) ...[ // 항상 이미지 섹션 노출
                    Row(
                      children: [
                        const Text(
                          '이미지',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${remaining.length + _newImages.length}/5',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Pretendard'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // 기존 이미지 (삭제되지 않은 것)
                          ...remaining.map((file) => _buildExistingImageItem(file)),
                          // 새로 추가한 이미지
                          ..._newImages.asMap().entries.map((e) => _buildNewImageItem(e.key, e.value)),
                          // 추가 버튼 (최대 5장)
                          if (remaining.length + _newImages.length < 5)
                            _buildAddImageButton(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 제목
                  const Text('제목', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Pretendard')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 내용
                  const Text('내용', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Pretendard')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contentController,
                    onChanged: (_) => setState(() {}),
                    maxLines: 4,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 지도 노출 토글
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      title: Text('지도 노출', style: TextStyle(color: Colors.grey[800], fontFamily: 'Pretendard', fontWeight: FontWeight.w600)),
                      subtitle: Text('노출 설정시 지도위에 표시됩니다.', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'Pretendard')),
                      value: _isShow,
                      onChanged: (v) => setState(() => _isShow = v),
                      activeThumbColor: const Color(0xFF4D91FF),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_canSave() && !_isSaving) ? _savePost : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_canSave() && !_isSaving) ? Colors.white : Colors.grey[300],
                        foregroundColor: (_canSave() && !_isSaving) ? const Color(0xFF4D91FF) : Colors.grey[600],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: (_canSave() && !_isSaving) ? 4 : 0,
                        shadowColor: (_canSave() && !_isSaving) ? Colors.black.withValues(alpha: 0.1) : Colors.transparent,
                      ),
                      child: _isSaving
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4D91FF)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('저장 중...', style: TextStyle(fontSize: 16, fontFamily: 'Pretendard', fontWeight: FontWeight.w700)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded, size: 20, color: _canSave() ? const Color(0xFF4D91FF) : Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(
                                  '수정 완료',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w700,
                                    color: _canSave() ? const Color(0xFF4D91FF) : Colors.grey[600],
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
      ),
    );
  }

  Widget _buildExistingImageItem(FileInfo file) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              file.fileUrl,
              width: 80,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 100,
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
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewImageItem(int index, File file) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              width: 80,
              height: 100,
              fit: BoxFit.cover,
            ),
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
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 80,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text('추가', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Pretendard')),
          ],
        ),
      ),
    );
  }
}
