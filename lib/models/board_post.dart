class BoardPost {
  final String profileImageUrl;
  final String nickname;
  final String location;
  final List<String> imageUrls;
  final String? title;
  final String content;
  final String likeCount;
  final String commentCount;

  BoardPost({
    required this.profileImageUrl,
    required this.nickname,
    required this.location,
    required this.imageUrls,
    this.title = '',
    required this.content,
    required this.likeCount,
    required this.commentCount,
  });

  factory BoardPost.fromJson(Map<String, dynamic> json) {
    return BoardPost(
      profileImageUrl: json['profileImageUrl'] as String,
      nickname: json['nickname'] as String,
      location: json['location'] as String,
      imageUrls: List<String>.from(json['imageUrls']),
      title: json['title'] as String,
      content: json['content'] as String,
      likeCount: json['likeCount'] as String,
      commentCount: json['commentCount'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profileImageUrl': profileImageUrl,
      'nickname': nickname,
      'location': location,
      'imageUrls': imageUrls,
      'title': title,
      'content': content,
      'likeCount': likeCount,
      'commentCount': commentCount,
    };
  }
} 