import 'package:unimal/service/board/model/file_info.dart';
import 'package:unimal/service/board/model/reply_info.dart';

class BoardPost {
  final String boardId;
  final String profileImage;
  final String email;
  final String nickname;
  final String title;
  final String content;
  final String streetName;
  final double? latitude;
  final double? longitude;
  final String show;
  final String mapShow;
  final List<FileInfo> fileInfoList;
  final int likeCount;
  final int replyCount;
  final String createdAt;
  final List<ReplyInfo> reply;
  final bool isLike;
  final bool isOwner;

  /// 공유 링크. **null 이면 공유할 수 없는 글이므로 버튼을 숨긴다.**
  ///
  /// URL 을 앱에서 조립하지 않고 서버가 완성해서 내려준다. 앱은 배포하면 못 고치기
  /// 때문에, 도메인이나 경로가 바뀌면 서버 배포 한 번으로 끝나야 한다.
  /// (서버 `ShareUrlFactory` KDoc 참고)
  ///
  /// "어떤 글이 공유 가능한가"의 판단도 서버에 있다. 앱은 null 여부만 본다 —
  /// 공개 정책이 바뀌어도 앱은 그대로다.
  final String? shareUrl;

  BoardPost({
    required this.boardId,
    required this.profileImage,
    required this.email,
    required this.nickname,
    required this.title,
    required this.content,
    required this.streetName,
    this.latitude,
    this.longitude,
    required this.show,
    required this.mapShow,
    required this.fileInfoList,
    required this.createdAt,
    required this.likeCount,
    required this.replyCount,
    required this.reply,
    required this.isLike,
    required this.isOwner,
    this.shareUrl,
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
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      show: json['show'] as String? ?? '',
      mapShow: json['mapShow'] as String? ?? '',
      // fileInfoList는 FileInfo 객체 리스트로 파싱
      fileInfoList: json['fileInfoList'] != null
          ? (json['fileInfoList'] as List)
              .map((e) => FileInfo.fromJson(e as Map<String, dynamic>))
              .toList()
          : <FileInfo>[],
      createdAt: json['createdAt'] as String? ?? '',
      // int 타입은 null일 경우 0으로 기본값 설정
      likeCount: json['likeCount'] as int? ?? 0,
      replyCount: json['replyCount'] as int? ?? 0,
      // reply는 ReplyInfo 객체 리스트로 파싱
      reply: json['reply'] != null
          ? (json['reply'] as List)
              .map((e) => ReplyInfo.fromJson(e as Map<String, dynamic>))
              .toList()
          : <ReplyInfo>[],
      isLike: json['isLike'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
      // 여기만 '' 폴백을 쓰지 않는다. null 이 "공유 불가"라는 의미를 갖기 때문에
      // 빈 문자열로 바꾸면 그 신호가 사라진다.
      shareUrl: json['shareUrl'] as String?,
    );
  }
//"fileInfoList":[{"fileId":"j8AaKOqB","fileUrl":"https://cdn.unimal.co.kr/images/aW1hZ2VfcGlja2VyX0FFMTNFOTk4LTJBQzktNEFFNy1BODZELUI2MkI2MDkyMEJCQy00MDM2NS0wMDAwMDI0NDcwN0NGRTdELmpwZw==-90ad052e8c7f49b697c55b09c8f64d6e.jpeg"},{"fileId":"wOqBW8yg","fileUrl":"https://cdn.unimal.co.kr/images/aW1hZ2VfcGlja2VyX0FFMjc3NTVGLTMzRTUtNDM1NS1BQUY2LTdDM0I2Rjg1Q0RFRS00MDM2NS0wMDAwMDI0NDcwQTQyMzIxLmpwZw==-c038f252b07b4094b425138ecb9c9f7c.jpeg"}]
//"reply":[]

  Map<String, dynamic> toJson() {
    return {
      'boardId': boardId,
      'profileImage': profileImage,
      'email': email,
      'nickname': nickname,
      'title': title,
      'content': content,
      'streetName': streetName,
      'latitude': latitude,
      'longitude': longitude,
      'show': show,
      'mapShow': mapShow,
      'fileInfoList': fileInfoList.map((e) => e.toJson()).toList(),
      'createdAt': createdAt,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'reply': reply.map((e) => e.toJson()).toList(),
      'isLike': isLike,
      'isOwner': isOwner,
      'shareUrl': shareUrl,
    };
  }
} 