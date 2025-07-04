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
  bool _showEmailLogin = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!_showEmailLogin) ...[
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
              ),
              Container(
                margin: EdgeInsets.only(bottom: 15),
                child: SizedBox(
                  width: 300,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showEmailLogin = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4D91FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '이메일로 로그인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                margin: EdgeInsets.only(bottom: 15),
                width: 300,
                child: TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: '이메일',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 15),
                width: 300,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 15),
                child: SizedBox(
                  width: 300,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // 이메일 로그인 로직
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4D91FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '로그인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 15),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showEmailLogin = false;
                    });
                  },
                  child: const Text(
                    '소셜 로그인으로 돌아가기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ))));
  }
}
