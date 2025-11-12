import 'dart:math';
import 'package:unimal/models/board_post.dart';

class BoardRepository {
  final Random _random = Random();

  // 실제 API 호출 시에는 http 패키지를 사용하여 구현
  Future<List<BoardPost>> getBoardPosts({int page = 1, int limit = 10}) async {
    // TODO: 실제 API 호출로 대체
    await Future.delayed(const Duration(seconds: 1)); // API 호출 시뮬레이션
    
    // 임시 데이터
    return List.generate(
      limit,
      (index) {
        // 랜덤으로 이미지 게시물 또는 텍스트 게시물 생성
        return _random.nextBool() ? _createImagePost(page, limit, index) : _createTextPost(page, limit, index);
      },
    );
  }

  BoardPost _createImagePost(int page, int limit, int index) {
    return BoardPost(
      profileImageUrl: 'https://i.pravatar.cc/300',
      nickname: '닉네임 ${(page - 1) * limit + index + 1}', // 페이지 번호를 닉네임에 추가 실제 적용시 삭제 예정
      location: '서울특별시 강남구 역삼동',
      imageUrls: [
        "https://play-lh.googleusercontent.com/rKTBYD8ykwgfHN_nFSwUErjQRPGjSEkStsjNQSUvgYGaEURpC2DMR7_1OdPu_dzysErv=w480-h960-rw",
        "https://search.pstatic.net/common/?src=http%3A%2F%2Fblogfiles.naver.net%2FMjAyNTAxMDFfMTgz%2FMDAxNzM1NzQyODU3NDUy.aVNDa7g0PLGGmPc4kVSIXWlagMUEqVzSiengkZa78g4g._PD32APBUvDV75GSx3mXowmrIjIqaGWxGvm4sOvy3ngg.JPEG%2FIMG_1553.JPG&type=sc960_832",
        "https://search.pstatic.net/common/?src=http%3A%2F%2Fblogfiles.naver.net%2FMjAyMTA1MjBfMjcy%2FMDAxNjIxNTIwNjQ3NjQy.aOBFYTd9GLD_C5KXLVN4EGRUrUKhQIl8Rg46oo15RGgg.RH2tVY4NMuR9l90ucuyGx3kh5_KOQROzHze9akTGIG0g.JPEG.hjincity%2FIMG_0478.JPG&type=sc960_832"
      ],
      title: 'Instagram 소라고둥님에게 소원을 빌어봐요! 귀여운 고양이와 강아지를 만날 수 있어요! ',
      content: 'Instagram 소라고둥님에게 소원을 빌어봐요! 귀여운 고양이와 강아지를 만날 수 있어요! '
        '지금 근처에 있는 동물들을 찾아보세요! 🐶🐱 아주 많은 이야기들이 있습니다~!! 🐾',
      likeCount: '560',
      commentCount: '12',
    );
  }

  BoardPost _createTextPost(int page, int limit, int index) {
    return BoardPost(
      profileImageUrl: 'https://i.pravatar.cc/300',
      nickname: '닉네임 ${(page - 1) * limit + index + 1}', // 페이지 번호를 닉네임에 추가 실제 적용시 삭제 예정
      location: '세종특별자치시 세종시 세종동 ㅁㄴㅇㅁㄴㅇㅁㄴㅇㅁㄴㅇ',
      imageUrls: [],
      title: 'Instagram 소라고둥님에게 소원을 빌어봐요! 귀여운 고양이와 강아지를 만날 수 있어요! ',
      content: 'Instagram 소라고둥님에게 소원을 빌어봐요! 귀여운 고양이와 강아지를 만날 수 있어요! '
        '지금 근처에 있는 동물들을 찾아보세요! 🐶🐱 아주 많은 이야기들이 있습니다~!! 🐾'
        '지금 근처에 있는 동물들을 찾아보세요! 🐶🐱 아주 많은 이야기들이 있습니다~!! 🐾',
      likeCount: '560',
      commentCount: '12',
    );
  }
} 