import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk_talk.dart';
import 'package:unimal/icon/custom_icon_icons.dart';
import 'package:http/http.dart' as http;

class KakaoButtonWidget extends StatelessWidget {
  const KakaoButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        try {
          OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
          print('카카오톡으로 로그인 성공 ${token.accessToken}');
          var url = Uri.http('localhost:8080', 'user/login/oauth2/kakao');
          print(url);
          var response = await http.get(url, headers: {"Authorization": token.accessToken});
          print('로그인 통신 ${response}');
        } catch (error) {
          print('카카오톡으로 로그인 실패 $error');
        }
      },
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
