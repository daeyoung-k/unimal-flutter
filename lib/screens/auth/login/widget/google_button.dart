import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:unimal/service/login/google_login_service.dart';

class GoogleButtonWidget extends StatelessWidget {
  const GoogleButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final googleLoginService = GoogleLoginService();
    return ElevatedButton(
      onPressed: () => googleLoginService.login(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFFFFFFF),
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
              child: SvgPicture.asset(
                'assets/icon/svg/google_icon.svg',
                width: 40,
                height: 40,
              )),
          Expanded(
            // 남은 공간을 차지하여 텍스트 중앙 정렬 효과
            child: Text(
              '구글 로그인',
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
