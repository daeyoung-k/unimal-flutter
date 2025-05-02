import 'package:flutter/material.dart';
import 'package:unimal/icon/custom_icon_icons.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';

class NaverButtonWidget extends StatelessWidget {
  const NaverButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final res = await FlutterNaverLogin.logIn();
        // final NaverLoginResult result = await FlutterNaverLogin.logIn();
        print(res);
        print(res.errorMessage);
        // NaverAccessToken res = await FlutterNaverLogin.currentAccessToken;
        // setState(() {
        //   accesToken = res.accessToken;
        //   tokenType = res.tokenType;
        // });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF5BC467),
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
              CustomIcon.naver_icon,
              size: 40,
              color: Colors.white,
            ),
          ),
          Expanded(
            // 남은 공간을 차지하여 텍스트 중앙 정렬 효과
            child: Text(
              '네이버 로그인',
              textAlign: TextAlign.center, // 텍스트 중앙 정렬
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
