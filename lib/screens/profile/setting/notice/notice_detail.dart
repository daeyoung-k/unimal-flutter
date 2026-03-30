import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/service/notice/model/notice_model.dart';

class NoticeDetailScreen extends StatelessWidget {
  final NoticeModel notice;

  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '공지사항',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontFamily: 'Pretendard',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(
              notice.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                fontFamily: 'Pretendard',
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            // 날짜
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '공지',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4D91FF),
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(notice.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black38,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[200], height: 1),
            const SizedBox(height: 20),
            // 본문
            Text(
              notice.content,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontFamily: 'Pretendard',
                height: 1.7,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.length < 10) return raw;
    return raw.substring(0, 10).replaceAll('-', '.');
  }
}
