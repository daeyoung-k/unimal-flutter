import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/service/login/manual_login_service.dart';

class ManualLoginFormWidget extends StatefulWidget {
  final VoidCallback onBackPressed;

  const ManualLoginFormWidget({
    super.key,
    required this.onBackPressed,
  });

  @override
  State<ManualLoginFormWidget> createState() => _ManualLoginFormWidgetState();
}

class _ManualLoginFormWidgetState extends State<ManualLoginFormWidget> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manualLoginService = ManualLoginService();
    return Column(
      children: [
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
              onPressed: () => manualLoginService.login(_emailController.text, _passwordController.text),
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
          margin: EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  // 아이디 찾기 페이지로 이동
                  Get.toNamed("/id-find");
                },
                child: const Text(
                  '아이디찾기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 12,
                color: Colors.white,
                margin: EdgeInsets.symmetric(horizontal: 8),
              ),
              TextButton(
                onPressed: () {
                  // 비밀번호 찾기 페이지로 이동
                  Get.toNamed("/password-find");
                },
                child: const Text(
                  '비밀번호찾기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 12,
                color: Colors.white,
                margin: EdgeInsets.symmetric(horizontal: 8),
              ),
              TextButton(
                onPressed: () {
                  Get.toNamed("/signup");
                },
                child: const Text(
                  '회원가입',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: EdgeInsets.only(bottom: 15),
          child: TextButton(
            onPressed: widget.onBackPressed,
            child: const Text(
              '소셜 로그인으로 돌아가기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
