class MapPost {
  final String id;
  final String title;
  final String content;
  final String streetName;
  final double latitude;
  final double longitude;
  final String createdAt;
  final String fileUrl;
  final int likeCount;
  final int replyCount;
  final double score;

  MapPost({
    required this.id,
    required this.title,
    required this.content,
    required this.streetName,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.fileUrl,
    required this.likeCount,
    required this.replyCount,
    required this.score,
  });

  factory MapPost.fromJson(Map<String, dynamic> json) {
    return MapPost(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      streetName: json['street_name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String? ?? '',
      fileUrl: json['file_url'] as String? ?? '',
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
