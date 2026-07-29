import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/marker/marker_group.dart';
import 'package:unimal/service/board/model/file_info.dart';
import 'package:unimal/service/map/models/map_post.dart';

MapPost _post({
  required String id,
  required double score,
  int files = 0,
  double lat = 37.5,
  double lng = 127.0,
}) {
  return MapPost(
    id: id,
    nickname: 'n',
    title: 't',
    content: 'c',
    streetName: 's',
    latitude: lat,
    longitude: lng,
    createdAt: '2026-07-28T00:00:00',
    fileInfoList: List.generate(
      files,
      (i) => FileInfo(fileId: '$id-$i', fileUrl: 'https://cdn/$id-$i.png'),
    ),
    likeCount: 0,
    replyCount: 0,
    score: score,
    isOwner: false,
    isLike: false,
  );
}

void main() {
  group('buildMarkerGroups', () {
    test('사진 글이 최고 score 가 아니어도 표시 대표가 된다', () {
      final groups = buildMarkerGroups([
        _post(id: 'text', score: 10004.1),
        _post(id: 'photo', score: 10004.0, files: 1),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.representative.id, 'photo');
      expect(groups.single.hasPhoto, isTrue);
    });

    test('랭킹 score 는 대표가 아니라 그룹 최댓값을 유지한다', () {
      final groups = buildMarkerGroups([
        _post(id: 'text', score: 10004.1),
        _post(id: 'photo', score: 3.1, files: 1),
      ]);

      expect(groups.single.representative.id, 'photo');
      expect(groups.single.rankScore, 10004.1);
    });

    test('대표를 앞으로 옮겨도 나머지는 score 내림차순을 유지한다', () {
      final groups = buildMarkerGroups([
        _post(id: 'text-hi', score: 100),
        _post(id: 'photo', score: 20, files: 2),
        _post(id: 'text-mid', score: 50),
        _post(id: 'text-lo', score: 10),
      ]);

      expect(
        groups.single.posts.map((p) => p.id).toList(),
        ['photo', 'text-hi', 'text-mid', 'text-lo'],
      );
    });

    test('사진 글이 없으면 최고 score 글이 대표이고 hasPhoto 는 false', () {
      final groups = buildMarkerGroups([
        _post(id: 'lo', score: 1),
        _post(id: 'hi', score: 9),
      ]);

      expect(groups.single.representative.id, 'hi');
      expect(groups.single.rankScore, 9);
      expect(groups.single.hasPhoto, isFalse);
    });

    test('사진 글이 여럿이면 그중 최고 score 가 대표', () {
      final groups = buildMarkerGroups([
        _post(id: 'photo-lo', score: 5, files: 1),
        _post(id: 'text', score: 99),
        _post(id: 'photo-hi', score: 7, files: 3),
      ]);

      expect(groups.single.representative.id, 'photo-hi');
      expect(groups.single.rankScore, 99);
    });

    test('11m 타일이 다르면 별개 그룹이다', () {
      // kStackGroupPrecision = 4 → 소수 넷째 자리가 다르면 다른 타일.
      final groups = buildMarkerGroups([
        _post(id: 'a', score: 1, lat: 37.5000),
        _post(id: 'b', score: 2, lat: 37.5001),
      ]);

      expect(groups, hasLength(2));
    });

    test('빈 입력은 빈 결과', () {
      expect(buildMarkerGroups(const <MapPost>[]), isEmpty);
    });
  });

  group('stackGroupKey', () {
    test('같은 11m 타일이면 같은 키', () {
      expect(stackGroupKey(37.50001, 127.00001),
          stackGroupKey(37.50004, 127.00004));
    });

    test('타일이 다르면 다른 키', () {
      expect(stackGroupKey(37.5000, 127.0),
          isNot(stackGroupKey(37.5001, 127.0)));
    });
  });
}
