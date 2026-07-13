import 'package:unimal/service/map/models/map_post.dart';

/// Holds navigation state for grouped posts on the map.
///
/// Groups are lists of [MapPost] at the same coordinate, ordered by score desc.
/// Sweeping next()/prev() moves within the current group first, and only
/// jumps to the next/previous group when the current group is exhausted.
///
/// Returns:
/// - `false` : moved within the same group (no camera jump needed)
/// - `true`  : crossed a group boundary (caller should move camera)
/// - `null`  : at the absolute beginning/end (caller may bounce)
class PostGroupNavigator {
  final List<List<MapPost>> groups;
  int _groupIndex;
  int _postIndex;
  int _imageIndex;

  PostGroupNavigator({
    required List<List<MapPost>> groups,
    int initialGroupIndex = 0,
    int initialPostIndex = 0,
    int currentImageIndex = 0,
  })  : groups = List.unmodifiable(groups.map<List<MapPost>>(List<MapPost>.unmodifiable)),
        _groupIndex = initialGroupIndex,
        _postIndex = initialPostIndex,
        _imageIndex = currentImageIndex {
    assert(groups.isNotEmpty, 'PostGroupNavigator requires non-empty groups');
    assert(
      initialGroupIndex >= 0 && initialGroupIndex < groups.length,
      'initialGroupIndex out of range',
    );
    assert(
      initialPostIndex >= 0 && initialPostIndex < groups[initialGroupIndex].length,
      'initialPostIndex out of range',
    );
  }

  int get groupIndex => _groupIndex;
  int get postIndex => _postIndex;
  int get currentImageIndex => _imageIndex;

  /// Update the currently-shown image index (e.g., when carousel scrolls).
  void updateImageIndex(int v) {
    _imageIndex = v;
  }

  MapPost get currentPost => groups[_groupIndex][_postIndex];
  List<MapPost> get currentGroup => groups[_groupIndex];

  /// Moves to the next post. Returns `false` if within same group,
  /// `true` if crossed group boundary, `null` if already at the end.
  bool? next() {
    if (_postIndex + 1 < groups[_groupIndex].length) {
      _postIndex++;
      _imageIndex = 0;
      return false;
    }
    if (_groupIndex + 1 < groups.length) {
      _groupIndex++;
      _postIndex = 0;
      _imageIndex = 0;
      return true;
    }
    return null;
  }

  /// Moves to the previous post. Returns `false` if within same group,
  /// `true` if crossed group boundary, `null` if already at the beginning.
  bool? prev() {
    if (_postIndex > 0) {
      _postIndex--;
      _imageIndex = 0;
      return false;
    }
    if (_groupIndex > 0) {
      _groupIndex--;
      _postIndex = groups[_groupIndex].length - 1;
      _imageIndex = 0;
      return true;
    }
    return null;
  }

  /// 게시글을 건너뛰고 다음 마커 그룹으로 바로 이동.
  /// 다음 그룹이 있으면 true, 없으면 null (경계).
  bool? nextGroup() {
    if (_groupIndex + 1 < groups.length) {
      _groupIndex++;
      _postIndex = 0;
      _imageIndex = 0;
      return true;
    }
    return null;
  }

  /// 게시글을 건너뛰고 이전 마커 그룹으로 바로 이동.
  /// 이전 그룹이 있으면 true, 없으면 null (경계).
  bool? prevGroup() {
    if (_groupIndex > 0) {
      _groupIndex--;
      _postIndex = 0;
      _imageIndex = 0;
      return true;
    }
    return null;
  }

  /// Jump to a specific group (e.g., when user taps a different marker).
  void jumpToGroup(int groupIndex) {
    assert(groupIndex >= 0 && groupIndex < groups.length);
    _groupIndex = groupIndex;
    _postIndex = 0;
    _imageIndex = 0;
  }

  /// Jump to a specific post within a specific group.
  /// 같은 자리 스택(A안) — 카드 스트립이 그룹 내 글 사이를 넘길 때 사용.
  void jumpTo(int groupIndex, int postIndex) {
    assert(groupIndex >= 0 && groupIndex < groups.length);
    assert(postIndex >= 0 && postIndex < groups[groupIndex].length);
    _groupIndex = groupIndex;
    _postIndex = postIndex;
    _imageIndex = 0;
  }
}
