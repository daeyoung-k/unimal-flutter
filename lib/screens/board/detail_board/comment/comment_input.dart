import 'dart:io';
import 'package:flutter/material.dart';

class CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const CommentInput({
    super.key, 
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
        // iOS 키보드 위에 테두리 추가
        border: Platform.isIOS
            ? const Border(
                top: BorderSide(
                  color: Color(0xFFE0E0E0),
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              // iOS 키보드 색상 설정 (dark: 어두운 키보드 - 상단 둥근 모서리가 더 잘 보임)
              decoration: InputDecoration(
                hintText: '댓글을 입력하세요...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontFamily: 'Pretendard',
                ),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF4D91FF),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: onSend,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}