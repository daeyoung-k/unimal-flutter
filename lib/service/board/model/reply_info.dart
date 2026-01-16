class ReplyInfo {
  final String id;
  final String boardId;
  final String? replyId;
  final bool reReplyYn;
  final String email;
  final String nickname;
  final String comment;
  final String createdAt;
  final bool isOwner;
  final bool isDel;

  ReplyInfo({
    required this.id,
    required this.boardId,
    required this.replyId,
    required this.reReplyYn,
    required this.email,
    required this.nickname,
    required this.comment,
    required this.createdAt,
    required this.isOwner,
    required this.isDel,
  });

  factory ReplyInfo.fromJson(Map<String, dynamic> json) {
    return ReplyInfo(
      id: json['id']?.toString() ?? '',
      boardId: json['boardId']?.toString() ?? '',
      replyId: json['replyId']?.toString(),
      reReplyYn: json['reReplyYn'] as bool? ?? false,
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      isOwner: json['isOwner'] as bool? ?? false,
      isDel: json['isDel'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boardId': boardId,
      'replyId': replyId,
      'reReplyYn': reReplyYn,
      'email': email,
      'nickname': nickname,
      'comment': comment,
      'createdAt': createdAt,
      'isOwner': isOwner,
      'isDel': isDel,
    };
  }
}