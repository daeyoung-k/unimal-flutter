import 'package:unimal/screens/map/marker/marker_constants.dart';
import 'package:unimal/service/map/models/map_post.dart';

/// 같은 자리 스택 그룹핑 좌표 키 ([kStackGroupPrecision], 4자리 ≈ 11m 타일).
/// 그룹핑과 펼침 숨김 가드가 반드시 같은 키를 쓰도록 한 곳에서 관리한다.
String stackGroupKey(double lat, double lng) =>
    '${lat.toStringAsFixed(kStackGroupPrecision)},'
    '${lng.toStringAsFixed(kStackGroupPrecision)}';

/// 같은 자리(11m 타일) 글 묶음.
///
/// **랭킹과 표시를 분리해서 들고 있다**
/// (설계: `docs/specs/2026-07-28-마커-사진-우선-대표-선정.md`).
/// - [rankScore] — 이 자리가 얼마나 중요한가. 크기 티어·zIndex·클러스터 대표 선정.
/// - [representative] — 무엇을 보여줄까. 아이콘·캡션·카드 첫 장·탭 대상.
///
/// 분리하지 않으면 참여도 높은 텍스트 글을 품은 스택이 대표가 사진 글로 바뀌면서
/// 하위 티어(42dp)로 내려앉는다.
class MarkerGroup {
  /// 표시 순서. `[0]` 이 표시 대표(사진 우선), 나머지는 score 내림차순.
  final List<MapPost> posts;

  /// 그룹 내 최고 score. 대표 글의 score 와 다를 수 있다.
  final double rankScore;

  const MarkerGroup({required this.posts, required this.rankScore});

  /// 표시 대표 — 사진 있는 글 중 최고 score. 사진이 없으면 최고 score 글.
  MapPost get representative => posts.first;

  /// 그룹에 사진이 하나라도 있는가. 사진이 있으면 반드시 대표가 사진 글이므로
  /// 대표만 보면 판정된다.
  bool get hasPhoto => posts.first.fileInfoList.isNotEmpty;
}

/// 글 목록을 11m 타일로 묶고, 그룹마다 랭킹 score 와 표시 대표를 정한다.
///
/// 1. score 내림차순 정렬 → 첫 원소가 [MarkerGroup.rankScore]
/// 2. 사진 있는 글 중 최고 score(=정렬 후 첫 사진 글)를 맨 앞으로 이동
///
/// 사진 글이 없거나 이미 맨 앞이면 순서를 건드리지 않는다.
List<MarkerGroup> buildMarkerGroups(Iterable<MapPost> posts) {
  final Map<String, List<MapPost>> grouped = {};
  for (final post in posts) {
    grouped
        .putIfAbsent(stackGroupKey(post.latitude, post.longitude), () => [])
        .add(post);
  }

  return grouped.values.map((list) {
    list.sort((a, b) => b.score.compareTo(a.score));
    final rankScore = list.first.score; // 정렬 직후 = 그룹 최댓값
    final photoIdx = list.indexWhere((p) => p.fileInfoList.isNotEmpty);
    if (photoIdx > 0) list.insert(0, list.removeAt(photoIdx));
    return MarkerGroup(posts: list, rankScore: rankScore);
  }).toList();
}

/// [pickClusterRepIndex] 입력 — 클러스터 자식 마커에서 선정에 필요한 값만 추린 것.
/// 플러그인 타입(`NClusterableMarkerInfo`)에 의존하지 않아 단위 테스트가 가능하다.
class ClusterChildRank {
  /// 이 자식 마커가 사진 썸네일을 갖고 있는가 (`tags['hasPhoto'] == '1'`).
  final bool hasPhoto;

  /// 이 자식 마커의 랭킹 score (`tags['score']`).
  final double score;

  const ClusterChildRank({required this.hasPhoto, required this.score});
}

/// 클러스터 표시 대표를 고른다 — **사진 자식 우선, 없으면 최고 score 자식.**
///
/// 스택 마커와 같은 규칙([buildMarkerGroups])을 클러스터에도 적용해, 사진 글을
/// 품은 클러스터가 점으로 그려지지 않게 한다. 동점이면 먼저 오는 자식을 쓴다.
///
/// 반환값은 [children] 의 인덱스. 빈 리스트면 `-1`.
int pickClusterRepIndex(List<ClusterChildRank> children) {
  var bestIdx = -1;
  var photoIdx = -1;
  var bestScore = double.negativeInfinity;
  var photoScore = double.negativeInfinity;

  for (var i = 0; i < children.length; i++) {
    final child = children[i];
    if (child.score > bestScore) {
      bestScore = child.score;
      bestIdx = i;
    }
    if (child.hasPhoto && child.score > photoScore) {
      photoScore = child.score;
      photoIdx = i;
    }
  }
  return photoIdx >= 0 ? photoIdx : bestIdx;
}
