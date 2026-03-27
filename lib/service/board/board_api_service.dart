import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/board/model/like_info.dart';
import 'package:unimal/state/secure_storage.dart';
import 'package:unimal/utils/api_client.dart';
import 'package:unimal/utils/api_uri.dart';
import 'package:unimal/utils/custom_alert.dart';
import 'package:unimal/utils/mime_type_utils.dart';

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
    if (response.statusCode == 200) {
      final bodyData = jsonDecode(utf8.decode(response.bodyBytes));
      final id = bodyData['data']['boardId']?.toString() ?? '';
      Get.toNamed('/detail-board', parameters: {'id': id});
    } else {
      _logger.e('게시글 생성 실패: ${response.statusCode} ${response.body}');
      _customAlert.showTextAlert('게시글 생성 실패', '게시글 생성에 실패했습니다.\n잠시 후 다시 시도해주세요.');
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
}
