import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/widget/login/google_button.dart';
import 'package:unimal/widget/login/kakao_button.dart';
import 'package:unimal/widget/login/naver_button.dart';

class LoginScreens extends StatefulWidget {
  const LoginScreens({super.key});

  @override
  State<LoginScreens> createState() => LoginStateScreens();
}

class LoginStateScreens extends State<LoginScreens> {
  _loginCheckAndRedirect() async {
    final authState = Get.find<AuthState>();
    if (authState.provider.value != LoginType.none) {
      Get.offAllNamed("/map");
    }
  }

  @override
  void initState() {
    super.initState();
    // build 가 종료되고 실행.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loginCheckAndRedirect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF4D91FF),
        body: SafeArea(
            child: Center(
                child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: EdgeInsets.only(bottom: 50),
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/img/universe-mise.png"),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(60),
              ),
            ),
            Container(
              margin: EdgeInsets.only(bottom: 50),
              child: Text(
                '우리 주변의 동물!\n어떤 친구들이 있을까요??',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(bottom: 15),
              child: KakaoButtonWidget(),
            ),
            Container(
              margin: EdgeInsets.only(bottom: 15),
              child: NaverButtonWidget(),
            ),
            Container(
              margin: EdgeInsets.only(bottom: 15),
              child: GoogleButtonWidget(),
            )
          ],
        ))));
  }
}
