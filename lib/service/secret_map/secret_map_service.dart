import 'package:unimal/service/secret_map/model/secret_map_info.dart';

/// 우리지도(구 비밀지도) API 서비스 — 현재는 목 데이터.
///
/// TODO(server): unimal-server 우리지도 API 완성 시 `ApiClient` + `ApiUri` 로
/// 교체한다 (BoardApiService 패턴). 메서드 시그니처는 유지.
class SecretMapService {
  /// 내가 속한 우리지도 목록.
  Future<List<SecretMapInfo>> getMyMaps() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockMaps;
  }

  /// 지도 생성. 생성된 지도 정보를 반환.
  Future<SecretMapInfo> createMap(String name) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return SecretMapInfo(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      inviteCode: 'NEW123',
      memberCount: 1,
      isOwner: true,
      members: const [SecretMapMember(nickname: '나', isOwner: true)],
    );
  }

  /// 초대 코드로 지도 조회 (합류 확인 시트용). 없는 코드면 null.
  Future<SecretMapInfo?> findMapByCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (code.trim().isEmpty) return null;
    return SecretMapInfo(
      id: 'joined_$code',
      name: '광진구 런닝지도',
      inviteCode: code,
      memberCount: 12,
      lastActivityAt:
          DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      members: const [SecretMapMember(nickname: '러닝짱', isOwner: true)],
    );
  }

  /// 지도 참여.
  Future<void> joinMap(String mapId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// 지도 글 목록 (마커 뷰 + 게시판 뷰 공용).
  Future<List<SecretMapPost>> getPosts(String mapId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockPosts;
  }

  // ---------------------------------------------------------------------
  // 목 데이터
  // ---------------------------------------------------------------------

  static final _now = DateTime.now();

  static String _ago({int hours = 0, int days = 0, int minutes = 0}) => _now
      .subtract(Duration(hours: hours, days: days, minutes: minutes))
      .toIso8601String();

  static final List<SecretMapInfo> _mockMaps = [
    SecretMapInfo(
      id: 'map_1',
      name: '광진구 런닝지도',
      inviteCode: 'RUN2026',
      memberCount: 12,
      lastActivityAt: _ago(hours: 3),
      hasNewPost: true,
      isOwner: true,
      members: const [
        SecretMapMember(nickname: '나', isOwner: true),
        SecretMapMember(nickname: '러닝짱'),
        SecretMapMember(nickname: '뚜벅이'),
        SecretMapMember(nickname: '한강러버'),
      ],
      markerPreview: const [
        SecretMapLatLng(37.5443, 127.0665),
        SecretMapLatLng(37.5385, 127.0823),
        SecretMapLatLng(37.5473, 127.0745),
        SecretMapLatLng(37.5316, 127.0663),
      ],
    ),
    SecretMapInfo(
      id: 'map_2',
      name: '길고양이 급식소 지도',
      inviteCode: 'CAT0707',
      memberCount: 5,
      lastActivityAt: _ago(days: 1),
      members: const [
        SecretMapMember(nickname: '캣맘', isOwner: true),
        SecretMapMember(nickname: '나'),
        SecretMapMember(nickname: '츄르요정'),
      ],
      markerPreview: const [
        SecretMapLatLng(37.5013, 127.0396),
        SecretMapLatLng(37.5081, 127.0632),
        SecretMapLatLng(37.4952, 127.0276),
      ],
    ),
  ];

  static final List<SecretMapPost> _mockPosts = [
    SecretMapPost(
      id: 'post_notice_1',
      type: SecretMapPostType.notice,
      authorNickname: '나',
      title: '이번 주 정기런 안내',
      content: '토요일 오전 7시 뚝섬유원지역 3번 출구에서 모여요!',
      createdAt: _ago(days: 2),
      replyCount: 4,
    ),
    SecretMapPost(
      id: 'post_story_1',
      type: SecretMapPostType.story,
      authorNickname: '러닝짱',
      title: '한강 야경 코스 최고',
      content: '오늘 10km 완주! 이 코스 야경이 진짜 예뻐요.',
      createdAt: _ago(hours: 3),
      likeCount: 8,
      replyCount: 3,
      latitude: 37.5443,
      longitude: 127.0665,
    ),
    SecretMapPost(
      id: 'post_story_2',
      type: SecretMapPostType.story,
      authorNickname: '뚜벅이',
      title: '어린이대공원 한 바퀴',
      content: '아침 공기 좋을 때 뛰기 딱 좋은 코스.',
      createdAt: _ago(days: 1),
      likeCount: 5,
      replyCount: 1,
      latitude: 37.5473,
      longitude: 127.0745,
    ),
    SecretMapPost(
      id: 'post_talk_1',
      type: SecretMapPostType.talk,
      authorNickname: '한강러버',
      content: '이번 주말에 비 온다는데 정기런 어떻게 하나요?',
      createdAt: _ago(hours: 5),
      replyCount: 6,
    ),
    SecretMapPost(
      id: 'post_talk_2',
      type: SecretMapPostType.talk,
      authorNickname: '러닝짱',
      content: '러닝화 추천 좀 해주세요! 발볼 넓은 편이에요.',
      createdAt: _ago(hours: 20),
      likeCount: 2,
      replyCount: 9,
    ),
    SecretMapPost(
      id: 'post_story_3',
      type: SecretMapPostType.story,
      authorNickname: '나',
      title: '건대입구 스트레칭 존',
      content: '런 끝나고 여기서 마무리 스트레칭 하기 좋아요.',
      createdAt: _ago(days: 3),
      likeCount: 3,
      latitude: 37.5385,
      longitude: 127.0823,
    ),
  ];
}
