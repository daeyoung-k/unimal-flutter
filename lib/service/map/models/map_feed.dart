import 'dart:convert';

import 'package:http/http.dart' as http;

/// 지도 바텀카드 피드 섹션 종류.
///
/// 서버는 앱 배포 없이 섹션을 추가할 수 있어야 한다(헤더 문구도 서버가 내려준다).
/// 그래서 파싱 단계에서 **모르는 타입은 그 섹션만 버린다** — 이 enum 에 unknown
/// 멤버를 두지 않는 이유다. UI 까지 unknown 이 흘러가면 화면에서 또 방어해야 한다.
enum MapFeedSectionType {
  latest,
  hot,
  nearby;

  /// 서버 문자열 → enum. 모르는 값이면 null (호출자가 그 섹션을 건너뛴다).
  static MapFeedSectionType? tryParse(String? raw) {
    switch (raw) {
      case 'LATEST':
        return MapFeedSectionType.latest;
      case 'HOT':
        return MapFeedSectionType.hot;
      case 'NEARBY':
        return MapFeedSectionType.nearby;
      default:
        return null;
    }
  }
}

/// 피드 카드 1장.
///
/// JSON은 snake_case(`board_id`, `thumbnail_url` 등)로 전송되고, Dart 프로퍼티는 camelCase다.
/// 직렬화 경계(`fromJson`)에서만 변환한다.
///
/// 서버가 `isLike`/`isOwner`/`score`/전체 이미지 목록을 일부러 뺐다 — 응답이
/// 사용자에 의존하지 않아야 캐시가 가능하기 때문이다. 그래서 카드 탭 시에는
/// `getBoardDetail` 로 상세를 다시 받아야 한다 (설계 §5).
class MapFeedItem {
  final String boardId;

  /// 마커/카드용 썸네일. 사진 없는 텍스트 글이거나 썸네일 파생 실패 시 null.
  final String? thumbnailUrl;
  final String title;
  final String content;
  final String streetName;
  final String? dong;
  final double latitude;
  final double longitude;
  final String nickname;
  final String? profileImage;
  final int likeCount;
  final int replyCount;
  final String createdAt;

  const MapFeedItem({
    required this.boardId,
    this.thumbnailUrl,
    required this.title,
    required this.content,
    required this.streetName,
    this.dong,
    required this.latitude,
    required this.longitude,
    required this.nickname,
    this.profileImage,
    required this.likeCount,
    required this.replyCount,
    required this.createdAt,
  });

  factory MapFeedItem.fromJson(Map<String, dynamic> json) {
    return MapFeedItem(
      boardId: json['board_id'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      streetName: json['street_name'] as String? ?? '',
      dong: json['dong'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      nickname: json['nickname'] as String? ?? '',
      profileImage: json['profile_image'] as String?,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// 섹션 1개. 서버가 3건 미만 섹션을 아예 제외하고 섹션 간 중복도 제거해 내려준다.
/// 앱은 받은 섹션을 순서대로 그리기만 한다 — 분기 로직을 클라이언트에 두지 않는다.
class MapFeedSection {
  final MapFeedSectionType type;

  /// 헤더 문구. 서버가 조립해 내려준다(`NEARBY` 는 동 이름이 들어간다).
  /// 앱에 하드코딩하지 않는 이유: 앱 배포 없이 문구를 바꿀 수 있어야 한다.
  final String title;
  final bool hasMore;
  final List<MapFeedItem> items;

  const MapFeedSection({
    required this.type,
    required this.title,
    required this.hasMore,
    required this.items,
  });

  /// 모르는 `type` 이면 null — 호출자가 이 섹션을 버린다.
  static MapFeedSection? tryFromJson(Map<String, dynamic> json) {
    final type = MapFeedSectionType.tryParse(json['type'] as String?);
    if (type == null) return null;
    final rawItems = json['items'];
    return MapFeedSection(
      type: type,
      title: json['title'] as String? ?? '',
      hasMore: json['has_more'] as bool? ?? false,
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(MapFeedItem.fromJson)
              // boardId 없는 아이템은 버린다. 카드 탭이 상세 조회로 이어지므로
              // id 가 없으면 아무것도 할 수 없고, 무엇보다 이게 **키 표기 계약
              // 위반의 조기 경보**다: 서버가 snake_case 대신 camelCase 로 내려주면
              // board_id 만 비고 type/title/content 는 그대로 매칭돼, 섹션이 정상
              // 렌더되면서 "좋아요 0 · 방금 전" 쓰레기 카드가 뜬다. 버리면 피드가
              // 아예 안 떠서 원인이 즉시 드러난다 (2026-07-30 최종 리뷰).
              .where((item) => item.boardId.isNotEmpty)
              .toList()
          : const <MapFeedItem>[],
    );
  }
}

class MapFeedResponse {
  /// 현재 행정동. 서버가 파라미터 또는 역지오코딩으로 확정한 값.
  /// `NEARBY` 섹션이 제외된 경우 null 일 수 있다.
  final String? dong;
  final List<MapFeedSection> sections;

  const MapFeedResponse({this.dong, required this.sections});

  factory MapFeedResponse.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    return MapFeedResponse(
      dong: json['dong'] as String?,
      sections: rawSections is List
          ? rawSections
              .whereType<Map<String, dynamic>>()
              .map(MapFeedSection.tryFromJson)
              .whereType<MapFeedSection>() // 모르는 타입 섹션 제거
              .toList()
          : const <MapFeedSection>[],
    );
  }
}

/// HTTP 응답 → 피드. 실패/파싱불가면 null.
/// `decodeMapPostsResponse`(board_api_service.dart)와 같은 형태 — HTTP 없이
/// 테스트할 수 있도록 최상위 함수로 둔다.
MapFeedResponse? decodeMapFeedResponse(http.Response response) {
  if (response.statusCode != 200) return null;
  try {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map) return null;
    final data = body['data'];
    if (data is! Map<String, dynamic>) return null;
    return MapFeedResponse.fromJson(data);
  } catch (_) {
    return null;
  }
}
