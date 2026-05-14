import 'package:unimal/service/board/model/file_info.dart';

class MapPost {
  final String id;
  final String nickname;
  final String? profileImage;
  final String title;
  final String content;
  final String streetName;
  final double latitude;
  final double longitude;
  final String createdAt;
  final List<FileInfo> fileInfoList;
  final int likeCount;
  final int replyCount;
  final double score;
  final bool isOwner;
  final bool isLike;

  MapPost({
    required this.id,
    required this.nickname,
    this.profileImage,
    required this.title,
    required this.content,
    required this.streetName,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.fileInfoList,
    required this.likeCount,
    required this.replyCount,
    required this.score,
    required this.isOwner,
    required this.isLike,
  });

  factory MapPost.fromJson(Map<String, dynamic> json) {
    return MapPost(
      id: json['id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      profileImage: json['profile_image'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      streetName: json['street_name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String? ?? '',
      fileInfoList: json['file_info_list'] != null
          ? (json['file_info_list'] as List)
              .map((e) => FileInfo.fromJson(e as Map<String, dynamic>))
              .toList()
          : <FileInfo>[],
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      isOwner: json['is_owner'] as bool? ?? false,
      isLike: json['is_like'] as bool? ?? false,
    );
  }
}
