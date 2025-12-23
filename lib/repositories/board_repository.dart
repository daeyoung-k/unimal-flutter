import 'package:unimal/models/board_post.dart';
import 'package:unimal/service/board/board_api_service.dart';

class BoardRepository {
  final BoardApiService _boardApiService = BoardApiService();

  // API에서 받아온 게시글 목록을 반환
  Future<List<BoardPost>> getBoardPosts({int page = 0}) async {
    try {
      // HTTP 통신으로 게시글 목록 가져오기
      final boardPostList = await _boardApiService.getBoardPostList(page);
      
      // 받아온 리스트 데이터를 그대로 반환
      // getBoardPostList는 이미 List<BoardPost>를 반환하므로 타입 변환 불필요
      return boardPostList;
    } catch (e) {
      // 에러 발생 시 빈 리스트 반환 또는 에러 처리
      print('게시글 목록 조회 실패: $e');
      return [];
    }
  }
} 