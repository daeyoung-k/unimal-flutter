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
    required this.groups,
    int initialGroupIndex = 0,
    int initialPostIndex = 0,
    int currentImageIndex = 0,
  })  : _groupIndex = initialGroupIndex,
        _postIndex = initialPostIndex,
        _imageIndex = currentImageIndex {
    assert(groups.isNotEmpty, 'PostGroupNavigator requires non-empty groups');
  }

  int get groupIndex => _groupIndex;
  int get postIndex => _postIndex;
  int get currentImageIndex => _imageIndex;
  set currentImageIndex(int v) => _imageIndex = v;

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

  /// Jump to a specific group (e.g., when user taps a different marker).
  void jumpToGroup(int groupIndex) {
    assert(groupIndex >= 0 && groupIndex < groups.length);
    _groupIndex = groupIndex;
    _postIndex = 0;
    _imageIndex = 0;
  }
}
