class BoardDetailModel {
  final String boardId;
  final String profileImageUrl;
  final String email;
  final String nickname;
  final String title;
  final String content;
  final String streenName;
  final String show;
  final String mapShow;
  final List<String> fileInfoList;
  final String likeCount;
  final String commentCount;
  final List<String> reply;
  final bool isOwner;  

  BoardDetailModel({
    required this.boardId,
    required this.profileImageUrl,
    required this.email,
    required this.nickname,
    required this.title,
    required this.content,
    required this.streenName,
    required this.show,
    required this.mapShow,
    required this.fileInfoList,
    required this.likeCount,
    required this.commentCount,
    required this.reply,
    required this.isOwner,
  });

  factory BoardDetailModel.fromJson(Map<String, dynamic> json) {
    return BoardDetailModel(
      boardId: json['boardId'] as String,
      profileImageUrl: json['profileImageUrl'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      streenName: json['streenName'] as String,
      show: json['show'] as String,
      mapShow: json['mapShow'] as String,
      fileInfoList: List<String>.from(json['fileInfoList']),
      likeCount: json['likeCount'] as String,
      commentCount: json['commentCount'] as String,
      reply: List<String>.from(json['reply']),
      isOwner: json['isOwner'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'boardId': boardId,
      'profileImageUrl': profileImageUrl,
      'email': email,
      'nickname': nickname,
      'title': title,
      'content': content,
      'streenName': streenName,
      'show': show,
      'mapShow': mapShow,
      'fileInfoList': fileInfoList,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'reply': reply,
      'isOwner': isOwner,
    };
  }
}