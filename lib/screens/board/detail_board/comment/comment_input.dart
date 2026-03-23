import 'dart:io';
import 'package:flutter/material.dart';

class CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final bool isLoading;
  final String? replyToNickname;
  final VoidCallback? onCancelReply;

  const CommentInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.focusNode,
    this.isLoading = false,
    this.replyToNickname,
    this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        border: Border(
          top: BorderSide(
            color: Platform.isIOS ? const Color(0xFFE5E7EB) : Colors.grey.shade200,
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 답글 모드 배너
          if (replyToNickname != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF6FF),
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16, color: Color(0xFF7AB3FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '@$replyToNickname 에게 답글 달기',
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        color: Color(0xFF7AB3FF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF7AB3FF)),
                  ),
                ],
              ),
            ),
          // 입력 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: replyToNickname != null ? '답글을 입력하세요...' : '댓글을 입력하세요...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                      color: Color(0xFF1F2937),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isLoading
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF7AB3FF), Color(0xFF5A9FFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isLoading ? const Color(0xFFD1D5DB) : null,
                    shape: BoxShape.circle,
                    boxShadow: isLoading
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF7AB3FF).withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: IconButton(
                    icon: isLoading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: isLoading ? null : onSend,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
