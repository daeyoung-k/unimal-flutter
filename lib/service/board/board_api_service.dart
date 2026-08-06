import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/board/model/like_info.dart';
import 'package:unimal/service/map/models/map_feed.dart';
import 'package:unimal/service/map/models/map_post.dart';
import 'package:unimal/state/secure_storage.dart';
import 'package:unimal/utils/api_client.dart';
import 'package:unimal/utils/api_uri.dart';
import 'package:unimal/utils/custom_alert.dart';
import 'package:unimal/utils/mime_type_utils.dart';

List<MapPost>? decodeMapPostsResponse(http.Response response) {
  if (response.statusCode != 200) return null;
  try {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final data = body['data'];
    if (data is! List) return null;
    return data
        .map((e) => MapPost.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return null;
  }
}

class BoardApiService {
  final _logger = Logger();
  final _secureStorage = SecureStorage();
  final _customAlert = CustomAlert();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _secureStorage.getAccessToken();
    return {
      'Content-Type': 'application/json;charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── 게시글 생성 (Multipart) ─────────────────────────────────────────
  Future<void> createBoard(
    String title,
    String content,
    List<File> imageFiles,
    bool isShow,
    double latitude,
    double longitude,
    String postalCode,
    String streetName,
    String? siDo,
    String? guGun,
    String? dong,
  ) async {
    final url = ApiUri.resolve('board/post');

    Future<http.MultipartRequest> buildRequest(String token) async {
      final req = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['title'] = title
        ..fields['content'] = content
        ..fields['latitude'] = latitude.toString()
        ..fields['longitude'] = longitude.toString()
        ..fields['postalCode'] = postalCode
        ..fields['streetName'] = streetName
        ..fields['siDo'] = siDo ?? ''
        ..fields['guGun'] = guGun ?? ''
        ..fields['dong'] = dong ?? ''
        ..fields['isShow'] = isShow ? 'PUBLIC' : 'PRIVATE';

      for (final file in imageFiles) {
        final fileName = file.path.split('/').last;
        final ext = fileName.split('.').last;
        final mimeType = ImageMimeType.fromExtension(ext) ?? ImageMimeType.defaultType;
        req.files.add(await http.MultipartFile.fromPath(
          'files', file.path,
          filename: fileName,
          contentType: mimeType.toMediaType(),
        ));
      }
      return req;
    }

    final token = await _secureStorage.getAccessToken() ?? '';
    final response = await ApiClient.multipart(buildRequest, token);
    _handleCreateBoardResponse(response);
  }

  void _handleCreateBoardResponse(http.Response response) {
    if (response.statusCode != 200) {
      _logger.e('게시글 생성 실패: ${response.statusCode} ${response.body}');
      _customAlert.showTextAlert('게시글 생성 실패', '게시글 생성에 실패했습니다.\n잠시 후 다시 시도해주세요.');
      throw Exception('게시글 생성 실패: ${response.statusCode}');
    }
  }

  // ── 게시글 상세 조회 ────────────────────────────────────────────────
  Future<BoardPost> getBoardDetail(String id) async {
    final url = ApiUri.resolve('board/post/$id');
    final headers = await _authHeaders();
    final response = await ApiClient.get(url, headers);

    if (response.statusCode != 200) {
      _logger.e('게시글 상세 조회 실패: ${response.statusCode}');
      _customAlert.showTextAlert('게시글 상세 조회 실패', '게시글을 불러오지 못했습니다.\n잠시 후 다시 시도해주세요.');
      throw Exception('게시글 상세 조회 실패: ${response.statusCode}');
    }

    final bodyData = jsonDecode(utf8.decode(response.bodyBytes));
    return BoardPost.fromJson(bodyData['data'] as Map<String, dynamic>);
  }

  // ── 지도 통합검색용 게시글 조회 ──────────────────────────────────────
  /// 지도 상단 검색창의 "게시글" 섹션에 쓰는 조회.
  ///
  /// getBoardPostList 와 두 가지가 다르다.
  /// 1) 실패해도 알럿을 띄우지 않는다 — 검색창은 타이핑 중 계속 호출되는 자리라
  ///    알럿이 뜨면 사용자 경험이 크게 나빠진다.
  /// 2) size 를 명시해 상위 몇 건만 받는다 — 드롭다운에 미리보기로 붙는 용도.
  ///
  /// 범위는 전국이다. 서버 PostListRequest 에 latitude/longitude/distance 가
  /// 이미 있으므로, 나중에 "내 주변 우선"이 필요해지면 파라미터만 얹으면 된다.
  Future<List<BoardPost>> searchPostsForMap(
    String keyword, {
    int size = 5,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.length < 2) return [];

    try {
      final url = ApiUri.resolve('board/post/list', {
        'page': '0',
        'size': size.toString(),
        'sortType': 'LATEST',
        'keyword': trimmed,
      });
      final headers = await _authHeaders();
      final response = await ApiClient.get(url, headers);

      if (response.statusCode != 200) {
        _logger.w('지도 통합검색 게시글 조회 실패: ${response.statusCode}');
        return [];
      }

      final bodyData = jsonDecode(utf8.decode(response.bodyBytes));
      final data = bodyData['data'];
      if (data is! List) return [];

      return data
          .map((e) => BoardPost.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.w('지도 통합검색 게시글 조회 오류: $e');
      return [];
    }
  }

  // ── 게시글 목록 조회 ────────────────────────────────────────────────
  Future<List<BoardPost>> getBoardPostList({
    int page = 0,
    String? keyword,
    String sortType = 'LATEST',
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'sortType': sortType,
    };
    if (keyword != null && keyword.isNotEmpty) queryParams['keyword'] = keyword;

    final url = ApiUri.resolve('board/post/list', queryParams);
    final headers = await _authHeaders();
    final response = await ApiClient.get(url, headers);

    if (response.statusCode == 200) {
      final bodyData = jsonDecode(utf8.decode(response.bodyBytes));
      return (bodyData['data'] as List)
          .map((e) => BoardPost.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    _logger.e('게시글 목록 조회 실패: ${response.statusCode}');
    _customAlert.showTextAlert('게시글 목록 조회 실패', '목록을 불러오지 못했습니다.\n잠시 후 다시 시도해주세요.');
    return [];
  }

  // ── 게시글 수정 ─────────────────────────────────────────────────────
  Future<bool> updateBoard({
    required String boardId,
    required String title,
    required String content,
    required bool isShow,
  }) async {
    final url = ApiUri.resolve('board/post/$boardId/update');
    final headers = await _authHeaders();
    final body = jsonEncode({
      'title': title,
      'content': content,
      'isShow': isShow ? 'PUBLIC' : 'PRIVATE',
      'isMapShow': 'SAME',
    });

    final response = await ApiClient.patch(url, headers, body: body);
    if (response.statusCode == 200) return true;

    _logger.e('게시글 수정 실패: ${response.statusCode}');
    return false;
  }

  // ── 게시글 삭제 ─────────────────────────────────────────────────────
  Future<bool> deleteBoard(String boardId) async {
    final url = ApiUri.resolve('board/post/$boardId/delete');
    final headers = await _authHeaders();
    final response = await ApiClient.delete(url, headers);

    if (response.statusCode == 200) return true;

    _logger.e('게시글 삭제 실패: ${response.statusCode}');
    return false;
  }

  // ── 댓글 작성 ───────────────────────────────────────────────────────
  Future<bool> createReply(String boardId, String comment, {String? replyId}) async {
    final url = ApiUri.resolve('board/post/$boardId/reply');
    final headers = await _authHeaders();
    final bodyMap = <String, String>{'comment': comment};
    if (replyId != null && replyId.isNotEmpty) bodyMap['replyId'] = replyId;
    final body = jsonEncode(bodyMap);

    final response = await ApiClient.post(url, headers, body: body);
    if (response.statusCode == 200) return true;

    _logger.e('댓글 작성 실패: ${response.statusCode}');
    return false;
  }

  // ── 댓글 수정 ───────────────────────────────────────────────────────
  Future<bool> updateReply(String boardId, String replyId, String comment) async {
    final url = ApiUri.resolve('board/post/$boardId/reply/$replyId/update');
    final headers = await _authHeaders();
    final body = jsonEncode({'comment': comment});

    final response = await ApiClient.patch(url, headers, body: body);
    if (response.statusCode == 200) return true;

    _logger.e('댓글 수정 실패: ${response.statusCode}');
    return false;
  }

  // ── 댓글 삭제 ───────────────────────────────────────────────────────
  Future<bool> deleteReply(String boardId, String replyId) async {
    final url = ApiUri.resolve('board/post/$boardId/reply/$replyId/delete');
    final headers = await _authHeaders();

    final response = await ApiClient.delete(url, headers);
    if (response.statusCode == 200) return true;

    _logger.e('댓글 삭제 실패: ${response.statusCode}');
    return false;
  }

  // ── 게시글 파일 업로드 (Multipart) ──────────────────────────────────
  Future<bool> uploadBoardFiles(String boardId, List<File> imageFiles) async {
    final url = ApiUri.resolve('board/post/$boardId/file/upload');

    Future<http.MultipartRequest> buildRequest(String token) async {
      final req = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token';
      for (final file in imageFiles) {
        final fileName = file.path.split('/').last;
        final ext = fileName.split('.').last;
        final mimeType = ImageMimeType.fromExtension(ext) ?? ImageMimeType.defaultType;
        req.files.add(await http.MultipartFile.fromPath(
          'files', file.path,
          filename: fileName,
          contentType: mimeType.toMediaType(),
        ));
      }
      return req;
    }

    final token = await _secureStorage.getAccessToken() ?? '';
    final response = await ApiClient.multipart(buildRequest, token);

    if (response.statusCode == 200) return true;
    _logger.e('이미지 업로드 실패: ${response.statusCode}');
    return false;
  }

  // ── 게시글 파일 삭제 ────────────────────────────────────────────────
  Future<bool> deleteBoardFiles(String boardId, List<String> fileIds) async {
    final url = ApiUri.resolve('board/post/$boardId/file/delete');
    final headers = await _authHeaders();
    final body = jsonEncode({'fileIds': fileIds});

    final response = await ApiClient.post(url, headers, body: body);
    if (response.statusCode == 200) return true;

    _logger.e('이미지 삭제 실패: ${response.statusCode}');
    return false;
  }

  // ── 내 게시글 목록 ──────────────────────────────────────────────────
  Future<List<BoardPost>> getMyPostList({
    String? keyword,
    String sortType = 'LATEST',
  }) async {
    final queryParams = <String, String>{'sortType': sortType};
    if (keyword != null && keyword.isNotEmpty) queryParams['keyword'] = keyword;

    final url = ApiUri.resolve('board/post/my/list', queryParams);
    final headers = await _authHeaders();
    final response = await ApiClient.get(url, headers);

    if (response.statusCode == 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final data = body['data'];
      if (data is List) {
        return data.map((e) => BoardPost.fromJson(e as Map<String, dynamic>)).toList();
      }
    }

    _logger.e('내 게시물 목록 조회 실패: ${response.statusCode}');
    return [];
  }

  // ── 내 게시글 수 ────────────────────────────────────────────────────
  Future<int?> getMyPostTotal() async {
    final url = ApiUri.resolve('board/post/total');
    final headers = await _authHeaders();
    final response = await ApiClient.get(url, headers);

    if (response.statusCode == 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final data = body['data'];
      return data is int ? data : 0;
    }

    _logger.e('내 게시물 수 조회 실패: ${response.statusCode}');
    return null;
  }

  // ── 받은 좋아요 수 ──────────────────────────────────────────────────
  Future<int?> getMyLikeTotal() async {
    final url = ApiUri.resolve('board/post/total/like');
    final headers = await _authHeaders();
    final response = await ApiClient.get(url, headers);

    if (response.statusCode == 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final data = body['data'];
      return data is int ? data : 0;
    }

    _logger.e('받은 좋아요 수 조회 실패: ${response.statusCode}');
    return null;
  }

  // ── 지도 마커 조회 ──────────────────────────────────────────────────
  Future<List<MapPost>?> getMapLocationPosts({
    required double latitude,
    required double longitude,
    int zoom = 14,
  }) async {
    try {
      final url = ApiUri.resolve('board/map/post', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'zoom': zoom.toString(),
      });
      final headers = await _authHeaders();
      final response = await ApiClient.get(url, headers);
      final posts = decodeMapPostsResponse(response);
      if (posts == null) {
        _logger.e('지도 마커 조회 실패: ${response.statusCode}');
      }
      return posts;
    } catch (e, st) {
      _logger.e('지도 마커 조회 예외', error: e, stackTrace: st);
      return null;
    }
  }

  // ── 내가 좋아요한 글 수 ─────────────────────────────────────────────
  Future<int> getMyLikedTotal() async {
    final url = ApiUri.resolve('board/post/like/stories/total');
    final headers = await _authHeaders();
    final response = await ApiClient.get(url, headers);

    if (response.statusCode == 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final data = body['data'];
      return data is int ? data : 0;
    }

    _logger.e('좋아요한 글 수 조회 실패: ${response.statusCode}');
    return 0;
  }

  // ── 내가 좋아요한 글 목록 (무한 스크롤) ────────────────────────────
  Future<List<BoardPost>> getMyLikedPostList({int page = 0, int size = 20}) async {
    final url = ApiUri.resolve('board/post/like/stories/list', {
      'page': page.toString(),
      'size': size.toString(),
    });
    final headers = await _authHeaders();
    final response = await ApiClient.get(url, headers);

    if (response.statusCode == 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final data = body['data'];
      if (data is List) {
        return data.map((e) => BoardPost.fromJson(e as Map<String, dynamic>)).toList();
      }
    }

    _logger.e('좋아요한 글 목록 조회 실패: ${response.statusCode}');
    return [];
  }

  // ── 좋아요 요청 ─────────────────────────────────────────────────────
  Future<LikeInfo?> requestLike(String boardId) async {
    final url = ApiUri.resolve('board/post/$boardId/like');
    final headers = await _authHeaders();
    final response = await ApiClient.get(url, headers);

    if (response.statusCode == 200) {
      final bodyData = jsonDecode(utf8.decode(response.bodyBytes));
      return LikeInfo.fromJson(bodyData['data']);
    }

    _logger.e('좋아요 요청 실패: ${response.statusCode}');
    _customAlert.showTextAlert('좋아요 요청 실패', '잠시 후 다시 시도해주세요.');
    return null;
  }

  // ── 지도 바텀카드 피드 ──────────────────────────────────────────────
  /// 섹션 피드 조회. 실패/파싱불가면 null (호출자가 시트를 숨긴다).
  ///
  /// 서버가 3건 미만 섹션 제외·섹션 간 중복 제제까지 해서 내려주므로 앱은
  /// 받은 섹션을 그대로 그린다.
  ///
  /// 주소(`siDo`/`guGun`/`dong`)는 넘기지 않는다 — 지도 화면이 현재 동을 모르고,
  /// 앱이 역지오코딩을 먼저 하면 순차 2 RTT 가 되어 이 API 의 존재 이유(1 RTT)가
  /// 깨진다. 서버가 gRPC 역지오코딩 폴백 + 캐시를 갖고 있다.
  Future<MapFeedResponse?> getMapFeed({
    required double latitude,
    required double longitude,
    required int zoom,
    bool refresh = false,
  }) async {
    try {
      final url = ApiUri.resolve('board/map/feed', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'zoom': zoom.toString(),
        if (refresh) 'refresh': 'true',
      });
      final headers = await _authHeaders();
      final response = await ApiClient.get(url, headers);
      final feed = decodeMapFeedResponse(response);
      if (feed == null) {
        _logger.e('지도 피드 조회 실패: ${response.statusCode}');
      }
      return feed;
    } catch (e, st) {
      _logger.e('지도 피드 조회 예외', error: e, stackTrace: st);
      return null;
    }
  }

  /// 피드 **섹션 1개**만 조회. 섹션별 새로고침 버튼이 쓴다.
  ///
  /// 서버는 이 요청을 받아도 내부적으로는 전체 피드를 계산한다 — 섹션들이 하나의
  /// 후보 풀을 `HOT → LATEST → NEAR` 순으로 나눠 갖는 구조라 서로 독립이 아니기
  /// 때문이다. 그 덕에 **부분 갱신 결과가 전체 조회 결과와 항상 일치한다**
  /// (같은 글이 두 섹션에 겹쳐 뜨지 않는다). 앱이 아끼는 건 응답 크기(약 1/3)와
  /// 화면 안정성이지 서버 연산이 아니다.
  ///
  /// [refresh] 는 서버의 60초 응답 캐시를 우회한다. 사용자가 버튼을 눌러서 온
  /// 요청이면 반드시 true 로 보내야 한다 — 아니면 같은 자리에서 1분간 직전과
  /// 똑같은 데이터가 돌아와 버튼이 고장난 것처럼 보인다.
  ///
  /// 반환값이 [MapFeedSectionResult] 인 이유는 "통신 실패"와 "그 섹션이 지금 없음"을
  /// 호출자가 구분해야 하기 때문이다 (전자는 화면 유지, 후자는 섹션 제거).
  Future<MapFeedSectionResult> getMapFeedSection({
    required double latitude,
    required double longitude,
    required int zoom,
    required MapFeedSectionType type,
    bool refresh = true,
  }) async {
    try {
      final url = ApiUri.resolve('board/map/feed/section', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'zoom': zoom.toString(),
        'type': type.requestValue,
        if (refresh) 'refresh': 'true',
      });
      final headers = await _authHeaders();
      final response = await ApiClient.get(url, headers);
      final result = decodeMapFeedSectionResponse(response);
      if (!result.isSuccess) {
        _logger.e('지도 피드 섹션 조회 실패: ${response.statusCode} '
            '(type=${type.requestValue})');
      }
      return result;
    } catch (e, st) {
      _logger.e('지도 피드 섹션 조회 예외', error: e, stackTrace: st);
      return const MapFeedSectionResult.failed();
    }
  }
}
