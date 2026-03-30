import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/profile/setting/notice/notice_detail.dart';
import 'package:unimal/service/notice/model/notice_model.dart';
import 'package:unimal/service/notice/notice_service.dart';

class NoticeListScreen extends StatefulWidget {
  const NoticeListScreen({super.key});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  final _noticeService = NoticeService();
  List<NoticeModel> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    // TODO: API 연동 후 아래 더미데이터 제거
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _notices = [
          NoticeModel(
            noticeId: '1',
            title: '유니멀 아틀라스 서비스 오픈 안내',
            content: '안녕하세요, 유니멀 아틀라스입니다.\n\n'
                '유니멀 아틀라스 서비스가 정식 오픈되었습니다.\n\n'
                '유니멀 아틀라스는 위치 기반 커뮤니티 서비스로, 내 주변 이웃들과 다양한 이야기를 나눌 수 있는 공간입니다.\n\n'
                '서비스 이용 중 불편한 점이나 문의사항이 있으시면 support@unimal.co.kr 로 연락해 주시기 바랍니다.\n\n'
                '앞으로도 더 나은 서비스를 위해 최선을 다하겠습니다.\n\n'
                '감사합니다.',
            createdAt: '2026-05-17',
          ),
        ];
        _isLoading = false;
      });
    }
  }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4D91FF)))
          : _notices.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: const Color(0xFF4D91FF),
                  onRefresh: _loadNotices,
                  child: ListView.separated(
                    itemCount: _notices.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (_, index) => _buildNoticeItem(_notices[index]),
                  ),
                ),
    );
  }

  Widget _buildNoticeItem(NoticeModel notice) {
    return InkWell(
      onTap: () => Get.to(() => NoticeDetailScreen(notice: notice)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      Expanded(
                        child: Text(
                          notice.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                            fontFamily: 'Pretendard',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(notice.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black38,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_outlined, size: 52, color: Colors.black12),
          SizedBox(height: 12),
          Text(
            '등록된 공지사항이 없습니다',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black38,
              fontFamily: 'Pretendard',
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.length < 10) return raw;
    return raw.substring(0, 10).replaceAll('-', '.');
  }
}
