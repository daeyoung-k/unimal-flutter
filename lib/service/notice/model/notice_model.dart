class NoticeModel {
  final String noticeId;
  final String title;
  final String content;
  final String createdAt;

  NoticeModel({
    required this.noticeId,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      noticeId: json['noticeId']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}
