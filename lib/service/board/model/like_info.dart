class LikeInfo {
  final bool isLike;
  final int? likeCount;

  LikeInfo({
    required this.isLike,
     this.likeCount,
  });

  factory LikeInfo.fromJson(Map<String, dynamic> json) {
    return LikeInfo(
      isLike: json['isLiked'] as bool? ?? false,
      likeCount: json['likeCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isLike': isLike,
      'likeCount': likeCount,
    };
  }
}
