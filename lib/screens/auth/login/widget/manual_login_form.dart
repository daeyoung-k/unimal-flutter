import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/utils/custom_alert.dart';
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
  final manualLoginService = ManualLoginService();
  final CustomAlert customAlert = CustomAlert();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  static const Color _primary = Color(0xFF4D91FF);
  static const Color _fieldBg = Color(0xFFF3F4F6);
  static const Color _labelColor = Color(0xFF374151);
  static const Color _hintColor = Color(0xFF9CA3AF);
  static const Color _dividerColor = Color(0xFFE5E7EB);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  void _manualLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      customAlert.showTextAlert("오류", "이메일과 비밀번호를 입력해주세요.");
      return;
    }
    if (!isValidEmail(_emailController.text)) {
      customAlert.showTextAlert("이메일 형식 오류", "올바른 이메일 형식을 입력해주세요.");
      return;
    }
    await manualLoginService.login(_emailController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 제목
        const Text(
          '이메일로 로그인',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 20,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),

        // 이메일 필드
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(
            fontSize: 15,
            fontFamily: 'Pretendard',
            color: _labelColor,
          ),
          decoration: InputDecoration(
            hintText: '이메일',
            hintStyle: const TextStyle(
              color: _hintColor,
              fontSize: 15,
              fontFamily: 'Pretendard',
            ),
            filled: true,
            fillColor: _fieldBg,
            prefixIcon: const Icon(Icons.mail_outline_rounded, color: _hintColor, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),

        // 비밀번호 필드
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(
            fontSize: 15,
            fontFamily: 'Pretendard',
            color: _labelColor,
          ),
          decoration: InputDecoration(
            hintText: '비밀번호',
            hintStyle: const TextStyle(
              color: _hintColor,
              fontSize: 15,
              fontFamily: 'Pretendard',
            ),
            filled: true,
            fillColor: _fieldBg,
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: _hintColor, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),

        // 로그인 버튼
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _manualLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
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
                fontFamily: 'Pretendard',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 아이디찾기 | 비밀번호찾기 | 회원가입
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Get.toNamed("/id-find"),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '아이디찾기',
                style: TextStyle(
                  color: _hintColor,
                  fontSize: 13,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(width: 1, height: 12, color: _dividerColor, margin: const EdgeInsets.symmetric(horizontal: 8)),
            TextButton(
              onPressed: () => Get.toNamed("/password-find"),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '비밀번호찾기',
                style: TextStyle(
                  color: _hintColor,
                  fontSize: 13,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(width: 1, height: 12, color: _dividerColor, margin: const EdgeInsets.symmetric(horizontal: 8)),
            TextButton(
              onPressed: () => Get.toNamed("/signup"),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '회원가입',
                style: TextStyle(
                  color: _primary,
                  fontSize: 13,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 소셜 로그인으로 돌아가기
        TextButton(
          onPressed: widget.onBackPressed,
          child: const Text(
            '← 소셜 로그인으로 돌아가기',
            style: TextStyle(
              color: _hintColor,
              fontSize: 14,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
