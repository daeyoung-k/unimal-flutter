class NoticeModel {
  final String id;
  final String type;
  final String title;
  final String content;
  final String createdAt;

  NoticeModel({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? 'NOTICE',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get typeLabel {
    switch (type) {
      case 'EVENT':
        return '이벤트';
      case 'UPDATE':
        return '업데이트';
      case 'MAINTENANCE':
        return '점검';
      case 'POLICY':
        return '정책';
      case 'GUIDE':
        return '이용 안내';
      case 'CAMPAIGN':
        return '캠페인';
      case 'NOTICE':
      default:
        return '공지';
    }
  }
}
