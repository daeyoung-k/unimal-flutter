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

  /// 공유 링크. null 이면 공유 버튼을 숨긴다.
  ///
  /// URL 을 앱에서 조립하지 않고 서버가 완성해서 내려준다 — 앱은 배포하면 못 고치므로
  /// 도메인이 바뀌면 서버 배포 한 번으로 끝나야 한다.
  ///
  /// 마커는 공개 글만 오므로 실제로는 항상 값이 있다. 그래도 nullable 로 두는 건
  /// 구버전 서버와 섞여 돌 때(배포 시차) 필드가 없을 수 있어서다.
  final String? shareUrl;

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
    this.shareUrl,
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
      // 여기만 '' 폴백을 쓰지 않는다. null 이 "공유 불가"라는 의미를 갖기 때문에
      // 빈 문자열로 바꾸면 그 신호가 사라진다.
      shareUrl: json['share_url'] as String?,
    );
  }
}
