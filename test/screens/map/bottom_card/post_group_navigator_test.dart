import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/bottom_card/post_group_navigator.dart';
import 'package:unimal/service/board/model/file_info.dart';
import 'package:unimal/service/map/models/map_post.dart';

MapPost _post(String id, double lat, double lng) => MapPost(
  id: id,
  nickname: 'tester',
  profileImage: null,
  title: id,
  content: '',
  streetName: '',
  latitude: lat,
  longitude: lng,
  createdAt: '2026-05-13T12:00:00',
  fileInfoList: <FileInfo>[],
  likeCount: 0,
  replyCount: 0,
  score: 0,
  isOwner: false,
);

void main() {
  group('PostGroupNavigator', () {
    test('next() within the same group does not jump camera', () {
      final groups = [
        [_post('a1', 1.0, 1.0), _post('a2', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups);

      expect(nav.currentPost.id, 'a1');
      final jumped = nav.next();
      expect(jumped, isFalse);
      expect(nav.currentPost.id, 'a2');
    });

    test('next() across groups jumps camera and resets postIndex/image', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0), _post('b2', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, currentImageIndex: 3);

      final jumped = nav.next();
      expect(jumped, isTrue);
      expect(nav.currentPost.id, 'b1');
      expect(nav.currentImageIndex, 0);
    });

    test('next() at the very end returns null sentinel and keeps position', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
      ];
      final nav = PostGroupNavigator(groups: groups);
      expect(nav.next(), isNull);
      expect(nav.currentPost.id, 'a1');
    });

    test('prev() within group does not jump camera', () {
      final groups = [
        [_post('a1', 1.0, 1.0), _post('a2', 1.0, 1.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, initialGroupIndex: 0, initialPostIndex: 1);
      expect(nav.prev(), isFalse);
      expect(nav.currentPost.id, 'a1');
    });

    test('prev() across groups jumps camera and goes to last post of prev group', () {
      final groups = [
        [_post('a1', 1.0, 1.0), _post('a2', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, initialGroupIndex: 1);
      final jumped = nav.prev();
      expect(jumped, isTrue);
      expect(nav.currentPost.id, 'a2');
      expect(nav.currentImageIndex, 0);
    });

    test('prev() at very beginning returns null sentinel', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
      ];
      final nav = PostGroupNavigator(groups: groups);
      expect(nav.prev(), isNull);
    });

    test('jumpToGroup resets indices and reports group coordinate', () {
      final groups = [
        [_post('a1', 1.0, 1.0), _post('a2', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, currentImageIndex: 4);
      nav.jumpToGroup(1);
      expect(nav.currentPost.id, 'b1');
      expect(nav.currentImageIndex, 0);
    });

    // --- nextGroup / prevGroup ---

    test('nextGroup()은 같은 그룹 내 게시글을 건너뛰고 다음 그룹으로 이동', () {
      final groups = [
        [_post('a1', 1.0, 1.0), _post('a2', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
        [_post('c1', 3.0, 3.0)],
      ];
      final nav = PostGroupNavigator(groups: groups);
      final result = nav.nextGroup();
      expect(result, isTrue);
      expect(nav.groupIndex, 1);
      expect(nav.postIndex, 0);
      expect(nav.currentImageIndex, 0);
    });

    test('nextGroup()이 마지막 그룹에서 null 반환', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, initialGroupIndex: 1);
      expect(nav.nextGroup(), isNull);
      expect(nav.groupIndex, 1);
    });

    test('prevGroup()은 이전 그룹으로 이동', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0), _post('b2', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, initialGroupIndex: 1);
      final result = nav.prevGroup();
      expect(result, isTrue);
      expect(nav.groupIndex, 0);
      expect(nav.postIndex, 0);
    });

    test('prevGroup()이 첫 그룹에서 null 반환', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups);
      expect(nav.prevGroup(), isNull);
      expect(nav.groupIndex, 0);
    });
  });
}
