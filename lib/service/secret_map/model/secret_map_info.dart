/// 우리지도(구 비밀지도, 폐쇄형 공유 지도) 도메인 모델.
///
/// 서버 API 미완성 상태의 프론트 선행 구현용 모델 —
/// 스펙: docs/specs/2026-07-11-비밀지도-UX.md
/// 서버 스펙 확정 시 unimal-server `2026-07-11-비밀지도-설계.md` 응답 형태에 맞춰
/// fromJson을 붙인다.
library;

/// 마커/미니맵 프리뷰용 좌표.
class SecretMapLatLng {
  final double latitude;
  final double longitude;

  const SecretMapLatLng(this.latitude, this.longitude);
}

/// 우리지도 글 타입.
/// - [story]: 위치 필수 — 지도 마커로 표시
/// - [talk]: 담소 — 위치 없음, 게시판 뷰 전용
/// - [notice]: 공지 — 방장 전용 작성, 게시판 뷰 상단 고정
enum SecretMapPostType { story, talk, notice }

class SecretMapPost {
  final String id;
  final SecretMapPostType type;
  final String authorNickname;
  final String? title;
  final String content;

  /// ISO-8601 작성 시각.
  final String createdAt;
  final int likeCount;
  final int replyCount;

  /// story 타입만 좌표를 가진다.
  final double? latitude;
  final double? longitude;

  const SecretMapPost({
    required this.id,
    required this.type,
    required this.authorNickname,
    this.title,
    required this.content,
    required this.createdAt,
    this.likeCount = 0,
    this.replyCount = 0,
    this.latitude,
    this.longitude,
  });
}

class SecretMapMember {
  final String nickname;
  final String? profileImage;
  final bool isOwner;

  const SecretMapMember({
    required this.nickname,
    this.profileImage,
    this.isOwner = false,
  });
}

class SecretMapInfo {
  final String id;
  final String name;

  /// 초대 코드 (`https://unimal.co.kr/m/{code}`).
  final String inviteCode;
  final int memberCount;

  /// ISO-8601 최근 활동 시각. 활동 없으면 null.
  final String? lastActivityAt;

  /// 마지막 확인 이후 새 글 여부 — 리스트 카드 뱃지.
  final bool hasNewPost;

  /// 내가 방장인지 — 공지 작성/멤버 강퇴/지도 설정 노출 조건.
  final bool isOwner;

  final List<SecretMapMember> members;

  /// 리스트 미니맵 프리뷰용 마커 좌표 (서버가 내려주는 목록).
  final List<SecretMapLatLng> markerPreview;

  const SecretMapInfo({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.memberCount,
    this.lastActivityAt,
    this.hasNewPost = false,
    this.isOwner = false,
    this.members = const [],
    this.markerPreview = const [],
  });
}
