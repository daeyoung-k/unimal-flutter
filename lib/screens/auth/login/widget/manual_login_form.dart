import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/theme/app_colors.dart';
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
  bool _isLoading = false;

  static const Color _hintColor = Color(0xFFCBD5E1);

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

  Future<void> _manualLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      customAlert.showTextAlert("오류", "이메일과 비밀번호를 입력해주세요.");
      return;
    }
    if (!isValidEmail(_emailController.text)) {
      customAlert.showTextAlert("이메일 형식 오류", "올바른 이메일 형식을 입력해주세요.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await manualLoginService.login(_emailController.text, _passwordController.text);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required AppColors colors,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _hintColor,
        fontSize: 15,
        fontFamily: 'Pretendard',
      ),
      filled: true,
      fillColor: colors.surface,
      prefixIcon: Icon(icon, color: _hintColor, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primaryStrong, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 제목
        Text(
          '이메일 로그인',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 19,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),

        // 이메일 필드
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: colors.textSecondary),
          decoration: _inputDecoration(hint: '이메일', icon: Icons.mail_outline_rounded, colors: colors),
        ),
        const SizedBox(height: 12),

        // 비밀번호 필드
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: colors.textSecondary),
          decoration: _inputDecoration(hint: '비밀번호', icon: Icons.lock_outline_rounded, colors: colors),
        ),
        const SizedBox(height: 12),

        // 로그인 버튼
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _manualLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              disabledBackgroundColor: colors.primary.withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '로그인',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'Pretendard'),
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
              child: Text('아이디찾기', style: TextStyle(color: colors.textMuted, fontSize: 13, fontFamily: 'Pretendard')),
            ),
            Container(width: 1, height: 12, color: colors.divider, margin: const EdgeInsets.symmetric(horizontal: 8)),
            TextButton(
              onPressed: () => Get.toNamed("/password-find"),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('비밀번호찾기', style: TextStyle(color: colors.textMuted, fontSize: 13, fontFamily: 'Pretendard')),
            ),
            Container(width: 1, height: 12, color: colors.divider, margin: const EdgeInsets.symmetric(horizontal: 8)),
            TextButton(
              onPressed: () => Get.toNamed("/signup"),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('회원가입', style: TextStyle(color: colors.primaryStrong, fontSize: 13, fontFamily: 'Pretendard', fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 소셜 로그인으로 돌아가기
        TextButton(
          onPressed: _isLoading ? null : widget.onBackPressed,
          child: Text(
            '← 소셜 로그인으로 돌아가기',
            style: TextStyle(color: colors.textMuted, fontSize: 14, fontFamily: 'Pretendard'),
          ),
        ),
      ],
    );
  }
}
