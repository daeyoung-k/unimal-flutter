class BoardPost {
  final String boardId;
  final String profileImage;
  final String email;
  final String nickname;
  final String title;
  final String content;
  final String streetName;
  final String show;
  final String mapShow;
  final List<String> fileInfoList;
  final int likeCount;
  final int replyCount;
  final String createdAt;
  final List<String> reply;
  final bool isOwner;  

  BoardPost({
    required this.boardId,
    required this.profileImage,
    required this.email,
    required this.nickname,
    required this.title,
    required this.content,
    required this.streetName,
    required this.show,
    required this.mapShow,
    required this.fileInfoList,
    required this.createdAt,
    required this.likeCount,
    required this.replyCount,
    required this.reply,
    required this.isOwner,
  });

  factory BoardPost.fromJson(Map<String, dynamic> json) {
    return BoardPost(
      // boardId는 서버에서 int로 올 수도 있으므로 String으로 변환
      boardId: json['boardId']?.toString() ?? '',
      profileImage: json['profileImage'] as String? ?? '',
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      streetName: json['streetName'] as String? ?? '',
      show: json['show'] as String? ?? '',
      mapShow: json['mapShow'] as String? ?? '',
      fileInfoList: [],
      createdAt: json['createdAt'] as String? ?? '',
      // int 타입은 null일 경우 0으로 기본값 설정
      likeCount: json['likeCount'] as int? ?? 0,
      replyCount: json['replyCount'] as int? ?? 0,
      // reply는 리스트이므로 null 체크 후 빈 리스트로 기본값 설정
      reply: json['reply'] != null 
          ? List<String>.from(json['reply'] as List)
          : <String>[],
      isOwner: json['isOwner'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'boardId': boardId,
      'profileImage': profileImage,
      'email': email,
      'nickname': nickname,
      'title': title,
      'content': content,
      'streetName': streetName,
      'show': show,
      'mapShow': mapShow,
      'fileInfoList': fileInfoList,
      'createdAt': createdAt,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'reply': reply,
      'isOwner': isOwner,
    };
  }
} 