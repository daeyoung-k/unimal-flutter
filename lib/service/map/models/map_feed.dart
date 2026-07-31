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
  nearby,

  /// 서버 `FeedSectionType.NEAR` — 현재 위치에서 가까운 순, 반경 제한 없음.
  /// 2026-07-30 기준 서버가 실제로 내려주는 유일한 타입이다. `latest`/`hot`/
  /// `nearby` 는 서버 주석에 "밀도가 오르면 추가하기로 정해져 있다"고 명시돼
  /// 있어 미리 남겨둔다 — 그때는 서버만 배포하면 앱은 이미 안다.
  near;

  /// 서버 문자열 → enum. 모르는 값이면 null (호출자가 그 섹션을 건너뛴다).
  static MapFeedSectionType? tryParse(String? raw) {
    switch (raw) {
      case 'LATEST':
        return MapFeedSectionType.latest;
      case 'HOT':
        return MapFeedSectionType.hot;
      case 'NEARBY':
        return MapFeedSectionType.nearby;
      case 'NEAR':
        return MapFeedSectionType.near;
      default:
        return null;
    }
  }

  /// enum → 서버 문자열. 섹션 단건 조회(`/board/map/feed/section?type=...`)에 쓴다.
  ///
  /// [tryParse] 의 역방향인데 **`name.toUpperCase()` 로 때우지 않는다.** 지금은
  /// 우연히 일치하지만, 서버 [FeedSectionType] 에 `NEAR_BY` 같은 언더스코어 값이
  /// 하나만 생겨도 조용히 깨진다. 매핑을 양쪽 모두 명시해두면 새 타입을 추가할 때
  /// 두 곳을 다 고치게 되고, 하나만 고치면 컴파일이 막아준다(switch 가 exhaustive).
  String get requestValue => switch (this) {
        MapFeedSectionType.latest => 'LATEST',
        MapFeedSectionType.hot => 'HOT',
        MapFeedSectionType.nearby => 'NEARBY',
        MapFeedSectionType.near => 'NEAR',
      };
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

  /// 마커/카드용 썸네일(400px 파생). 사진 없는 텍스트 글이거나 썸네일 파생 실패 시 null.
  final String? thumbnailUrl;

  /// 원본 이미지. 서버 `MapFeedCard.imageUrl` — 풀폭 카드에서는 400px 파생(`thumbnailUrl`)이
  /// 흐릿하므로 카드 크기에 따라 골라 쓰라고 내려준다. **지금은 쓰지 않는다** — 현재
  /// 피드 카드는 116dp 정사각 썸네일이라 400px 파생으로 충분하다. 풀폭 카드가 생기면
  /// 그때 사용한다. 파싱만 해두고 필드를 보존한다.
  final String? imageUrl;
  final String title;
  final String content;
  final String streetName;

  /// 앱 모델에만 있는 필드 — 서버 `MapFeedCard` 에도 `dong` 이 있어 계속 내려온다
  /// (2026-07-30 서버 DTO 확인). 응답 최상위(`MapFeedResponse`)에는 `dong` 이 없다
  /// (아래 [MapFeedResponse.dong] 참고).
  final String? dong;
  final double latitude;
  final double longitude;

  /// 현재 지도 중심에서의 거리(미터). 서버 `MapFeedCard.distanceMeters` — 반경
  /// 제한이 없어 수백 km 떨어진 글일 수 있다. 카드에 노출해 탭했을 때 지도가
  /// 갑자기 먼 곳으로 튀어도 혼란스럽지 않게 한다.
  final int distanceMeters;
  final String nickname;
  final String? profileImage;
  final int likeCount;
  final int replyCount;
  final String createdAt;

  const MapFeedItem({
    required this.boardId,
    this.thumbnailUrl,
    this.imageUrl,
    required this.title,
    required this.content,
    required this.streetName,
    this.dong,
    required this.latitude,
    required this.longitude,
    this.distanceMeters = 0,
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
      imageUrl: json['image_url'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      streetName: json['street_name'] as String? ?? '',
      dong: json['dong'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distance_meters'] as num?)?.toInt() ?? 0,
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
  /// 현재 행정동. **서버 `MapFeedResponse` 에는 이 필드가 없다** (2026-07-30
  /// 서버 DTO 확인 — `sections` 만 있다). JSON 에 `dong` 키가 없으면 아래
  /// `fromJson` 이 그대로 null 을 넣으므로 무해하다. 필드는 제거하지 않고
  /// nullable 로 남겨둔다 — 나중에 서버가 최상위 `dong` 을 다시 내려주게 되면
  /// 이 자리를 그대로 쓸 수 있고, 지우면 되살릴 때 diff 가 커진다.
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

/// 섹션 단건 조회 결과.
///
/// **"통신 실패"와 "그 섹션이 지금 없음"을 구분해야 한다.** 서버는 적응형 섹션이라
/// 요청한 섹션이 이번 계산에서 안 만들어지면 `data: null` 을 200 으로 내려주는데,
/// 이건 정상 응답이고 앱은 그 섹션을 화면에서 **지워야** 한다. 반면 네트워크 오류나
/// 파싱 실패면 기존 섹션을 **유지해야** 한다. 둘 다 null 로 뭉뚱그리면 잠깐의
/// 통신 오류에 멀쩡한 섹션이 사라진다.
class MapFeedSectionResult {
  const MapFeedSectionResult._(this.section, this.isSuccess);

  /// 조회 성공. [section] 이 null 이면 "그 섹션은 지금 존재하지 않는다"는 뜻.
  const MapFeedSectionResult.loaded(MapFeedSection? section)
      : this._(section, true);

  /// 통신/파싱 실패. 호출자는 기존 화면을 그대로 둔다.
  const MapFeedSectionResult.failed() : this._(null, false);

  final MapFeedSection? section;
  final bool isSuccess;

  /// 성공했는데 섹션이 없는 경우 — 화면에서 제거해야 하는 상태.
  bool get isRemoved => isSuccess && section == null;
}

/// HTTP 응답 → 섹션 단건. `decodeMapFeedResponse` 와 달리 **null 데이터를 성공으로
/// 취급한다** ([MapFeedSectionResult] 주석 참고).
MapFeedSectionResult decodeMapFeedSectionResponse(http.Response response) {
  if (response.statusCode != 200) return const MapFeedSectionResult.failed();
  try {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map) return const MapFeedSectionResult.failed();
    final data = body['data'];
    if (data == null) return const MapFeedSectionResult.loaded(null);
    if (data is! Map<String, dynamic>) {
      return const MapFeedSectionResult.failed();
    }
    // 모르는 type 이면 tryFromJson 이 null 을 준다. 이건 "섹션 없음"이 아니라
    // 계약 위반이므로 실패로 본다 — 지우면 사용자는 이유를 알 수 없다.
    final section = MapFeedSection.tryFromJson(data);
    if (section == null) return const MapFeedSectionResult.failed();
    return MapFeedSectionResult.loaded(section);
  } catch (_) {
    return const MapFeedSectionResult.failed();
  }
}
