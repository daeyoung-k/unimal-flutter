import 'package:flutter/material.dart';
import 'package:unimal/icon/custom_icon_icons.dart';
import 'package:unimal/service/login/kakao_login_service.dart';

class KakaoButtonWidget extends StatelessWidget {
  const KakaoButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final kakaoLoginService = KakaoLoginService();
    return ElevatedButton(
      onPressed: () => kakaoLoginService.login(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFFBE750), // 카카오 옐로우
        maximumSize: Size(320, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25), // 모서리 둥글게
        ),
        elevation: 0, // 그림자 제거
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 로고와 텍스트 사이 간격
          Align(
            alignment: Alignment.centerLeft,
            child: Icon(
              CustomIcon.kakao_icon,
              size: 40,
              color: Colors.black,
            ),
          ),
          Expanded(
            // 남은 공간을 차지하여 텍스트 중앙 정렬 효과
            child: Text(
              '카카오 로그인',
              textAlign: TextAlign.center, // 텍스트 중앙 정렬
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
