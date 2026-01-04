import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/auth/authentication_service.dart';
import 'package:unimal/screens/widget/alert/custom_alert.dart';
import 'package:unimal/state/secure_storage.dart';
import 'package:unimal/utils/mime_type_utils.dart';

class BoardApiService {
  var logger = Logger();
  var host = Platform.isAndroid
      ? dotenv.env['ANDORID_SERVER']
      : dotenv.env['IOS_SERVER'];

  final SecureStorage _secureStorage = SecureStorage();
  final CustomAlert _customAlert = CustomAlert();
  final AuthenticationCodeService _authService = AuthenticationCodeService();

  Future<void> createBoard(
    String title,
    String content,
    List<File> imageFiles, // String imageUrls 대신 File 리스트로 변경
    bool isShow,
    double latitude,
    double longitude,
    String postalCode,
    String streetName,
    String? siDo,
    String? guGun,
    String? dong,
  ) async {
    var url = Uri.http(host.toString(), 'board/post');
    // MultipartRequest 생성
    var request = http.MultipartRequest('POST', url);

    // Bearer token 헤더 추가
    String? accessToken = await _secureStorage.getAccessToken();
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    // 텍스트 필드들 추가
    request.fields['title'] = title;
    request.fields['content'] = content;
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    request.fields['postalCode'] = postalCode;
    request.fields['streetName'] = streetName;
    request.fields['siDo'] = siDo ?? '';
    request.fields['guGun'] = guGun ?? '';
    request.fields['dong'] = dong ?? '';
    request.fields['isShow'] = isShow == true ? 'PUBLIC' : 'PRIVATE';

    // 파일들 추가
    for (int i = 0; i < imageFiles.length; i++) {
      var file = imageFiles[i];
      var fileName = file.path.split('/').last;
      var fileExtension = fileName.split('.').last;
      
      // 파일 확장자에 따른 MIME 타입 결정
      var mimeType = ImageMimeType.fromExtension(fileExtension) ?? ImageMimeType.defaultType;
      var contentType = mimeType.toMediaType();
      
      var multipartFile = await http.MultipartFile.fromPath(
        'files', // 서버에서 받는 필드명
        file.path,
        filename: fileName,
        contentType: contentType,
      );
      request.files.add(multipartFile);
    }

    // 요청 전송
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      var bodyData = jsonDecode(utf8.decode(response.bodyBytes));
      final id = bodyData['data']['boardId'];
      Get.toNamed(
        '/detail-board', 
        parameters: {
        'id': id ?? '',
      });
    } else {
      logger.e('게시글 생성 실패: ${response.statusCode}');
      logger.e('에러 메시지: ${response.body}');
      _customAlert.showTextAlert("게시글 생성 실패", "게시글 생성 실패 입니다.\n잠시후에 다시 시도 해주세요.");
    }
  }


  Future<BoardPost> getBoardDetail(String id) async {
    var url = Uri.http(host.toString(), 'board/post/$id');
    var headers = {"Content-Type": "application/json;charset=utf-8"};
    
    String? accessToken = await _secureStorage.getAccessToken();
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    var response = await http.get(url, headers: headers);
    
    // HTTP 응답 상태 코드 확인
    if (response.statusCode != 200) {
      logger.e('게시글 상세 조회 실패: ${response.statusCode}');
      logger.e('에러 메시지: ${response.body}');
      _customAlert.showTextAlert("게시글 상세 조회 실패", "게시글 상세 조회 실패 입니다.\n잠시후에 다시 시도 해주세요.");
    }
    
    // JSON 파싱
    var bodyData = jsonDecode(utf8.decode(response.bodyBytes));
    
    // 응답 데이터 확인 및 매핑
    if (bodyData['data'] == null) {
      logger.e('응답 데이터가 없습니다.');
      _customAlert.showTextAlert("응답 데이터 없음", "응답 데이터 없음.\n잠시후에 다시 시도 해주세요.");
    }
    
    // BoardDetailModel로 매핑
    var result = BoardPost.fromJson(bodyData['data'] as Map<String, dynamic>);
    return result;
  }

  Future<List<BoardPost>> getBoardPostList({int page = 0}) async {
    var url = Uri.http(host.toString(), 'board/post/list', {
      'page': page.toString(),
    });
    var headers = {"Content-Type": "application/json;charset=utf-8"};

    String? accessToken = await _secureStorage.getAccessToken();
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    
    var response = await http.get(url, headers: headers);
    
    // 401 에러 발생 시 토큰 재발급 후 재시도
    if (response.statusCode == 401) {
      try {
        // 토큰 재발급
        await _authService.tokenReIssue();
        
        // 새로운 accessToken으로 재시도
        String? newAccessToken = await _secureStorage.getAccessToken();
        if (newAccessToken != null) {
          headers['Authorization'] = 'Bearer $newAccessToken';
        }
        
        var retryResponse = await http.get(url, headers: headers);
        if (retryResponse.statusCode != 200) {
          logger.e('게시글 목록 조회 실패 (재시도 후): ${retryResponse.statusCode}');
          logger.e('에러 메시지: ${retryResponse.body}');
          _customAlert.showTextAlert("게시글 목록 조회 실패", "게시글 목록 조회 실패 입니다.\n잠시후에 다시 시도 해주세요.");
          throw Exception('게시글 목록 조회 실패: ${retryResponse.statusCode}');
        }
        
        var bodyData = jsonDecode(utf8.decode(retryResponse.bodyBytes));
        var result = (bodyData['data'] as List)
            .map((e) => BoardPost.fromJson(e as Map<String, dynamic>))
            .toList()
            .cast<BoardPost>();
        
        return result;
      } catch (e) {
        logger.e('토큰 재발급 실패 또는 재시도 실패: $e');
        _customAlert.showTextAlert("인증 오류", "인증에 실패했습니다.\n다시 로그인해주세요.");
        throw Exception('토큰 재발급 실패: $e');
      }
    }
    
    if (response.statusCode != 200) {
      logger.e('게시글 목록 조회 실패: ${response.statusCode}');
      logger.e('에러 메시지: ${response.body}');
      _customAlert.showTextAlert("게시글 목록 조회 실패", "게시글 목록 조회 실패 입니다.\n잠시후에 다시 시도 해주세요.");
      throw Exception('게시글 목록 조회 실패: ${response.statusCode}');
    }
    
    var bodyData = jsonDecode(utf8.decode(response.bodyBytes));
    
    // bodyData['data']는 List<dynamic> 타입
    // map()으로 각 요소를 BoardPost.fromJson()으로 변환
    // toList()로 List<BoardPost> 타입으로 변환
    // as List<BoardPost>는 타입 안전성을 위한 명시적 캐스팅 (실제로는 불필요할 수 있음)
    var result = (bodyData['data'] as List)
        .map((e) => BoardPost.fromJson(e as Map<String, dynamic>))
        .toList()
        .cast<BoardPost>();
    
    return result;
  }
}
