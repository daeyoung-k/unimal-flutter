import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/auth/login/widget/manual_login_form.dart';
import 'package:unimal/service/login/kakao_login_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/service/login/naver_login_service.dart';
import 'package:unimal/service/login/google_login_service.dart';
import 'package:unimal/state/auth_state.dart';

// 테마: 틸 #00ACC1 - 탐험, 발견, 신선함
class LoginScreen4 extends StatefulWidget {
  const LoginScreen4({super.key});

  @override
  State<LoginScreen4> createState() => _LoginScreen4State();
}

class _LoginScreen4State extends State<LoginScreen4> {
  bool _showEmailLogin = false;

  static const Color _primary = Color(0xFF00ACC1);
  static const Color _primaryDark = Color(0xFF006978);
  static const Color _accent = Color(0xFF4DD0E1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = Get.find<AuthState>();
      if (authState.provider.value != LoginType.none) {
        Get.offAllNamed("/map");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF26C6DA),
              _primary,
              _primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    _AppIcon(
                      iconColor: _primary,
                      badgeColor: _accent,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '스토맵',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '지도 위에 당신의 이야기를 남기세요',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryDark.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        child: _showEmailLogin
                            ? _EmailLoginSection(
                                onBack: () =>
                                    setState(() => _showEmailLogin = false),
                              )
                            : _SocialLoginSection(
                                onEmailLogin: () =>
                                    setState(() => _showEmailLogin = true),
                              ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 24),
                      child: Text(
                        '로그인하면 서비스 이용약관 및 개인정보 보호정책에 동의하게 됩니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final Color iconColor;
  final Color badgeColor;

  const _AppIcon({required this.iconColor, required this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7FA),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.location_on, size: 52, color: iconColor),
        ),
        Positioned(
          bottom: -6,
          right: -6,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _SocialLoginSection extends StatelessWidget {
  final VoidCallback onEmailLogin;

  const _SocialLoginSection({required this.onEmailLogin});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '시작하기',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 20,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        _LoginButton(
          onPressed: () => KakaoLoginService().login(),
          backgroundColor: const Color(0xFFFEE500),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.chat_bubble, color: Colors.black87, size: 22),
              SizedBox(width: 10),
              Text(
                '카카오로 시작하기',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LoginButton(
          onPressed: () => NaverLoginService().login(),
          backgroundColor: const Color(0xFF03C75A),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    'N',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '네이버로 시작하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LoginButton(
          onPressed: () => GoogleLoginService().login(),
          backgroundColor: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/icon/svg/google_icon.svg',
                  width: 22, height: 22),
              const SizedBox(width: 10),
              const Text(
                '구글로 시작하기',
                style: TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: onEmailLogin,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.mail_outline, color: Color(0xFF888888), size: 18),
              SizedBox(width: 6),
              Text(
                '이메일로 로그인',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 14,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Widget child;
  final BoxBorder? border;

  const _LoginButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.child,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: border,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _EmailLoginSection extends StatelessWidget {
  final VoidCallback onBack;

  const _EmailLoginSection({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ManualLoginFormWidget(onBackPressed: onBack);
  }
}
