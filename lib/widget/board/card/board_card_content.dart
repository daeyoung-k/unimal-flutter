
import 'package:flutter/material.dart';
import 'package:unimal/widget/action/action_icon_button.dart';

class BoardCardContent extends StatelessWidget {
  final String content;
  final String? likeCount;
  final String? commentCount;
  final int maxLine;
  final VoidCallback? onTap;
  const BoardCardContent({super.key, required this.content, this.likeCount = "0", this.commentCount = "0", required this.maxLine, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ActionIconButton(icon: Icons.favorite_border, count: likeCount!, onTap: () => onTap),
              SizedBox(width: 16),
              ActionIconButton(icon: Icons.chat_bubble_outline, count: commentCount!, onTap: () => onTap),
              SizedBox(width: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            maxLines: maxLine,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14,
                fontFamily: 'InstagramSans',
                fontWeight: FontWeight.w400
              ),
          ),
        ],
      ),
    );
  }
}