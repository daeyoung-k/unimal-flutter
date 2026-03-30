import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/auth/login/widget/manual_login_form.dart';
import 'package:unimal/service/login/kakao_login_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/service/login/naver_login_service.dart';
import 'package:unimal/service/login/google_login_service.dart';
import 'package:unimal/state/auth_state.dart';

class LoginScreens extends StatefulWidget {
  const LoginScreens({super.key});

  @override
  State<LoginScreens> createState() => _LoginScreensState();
}

class _LoginScreensState extends State<LoginScreens>
    with SingleTickerProviderStateMixin {
  bool _showEmailLogin = false;

  static const Color _primary = Color(0xFF7AB3FF);
  static const Color _primaryDark = Color(0xFF3578E5);

  late AnimationController _ctrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;
  late Animation<double> _bottomFade;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.45, curve: Curves.elasticOut)),
    );
    _logoFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );
    _titleSlide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 0.55, curve: Curves.easeOut)),
    );
    _titleFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 0.5, curve: Curves.easeOut)),
    );
    _cardSlide = Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 0.8, curve: Curves.easeOut)),
    );
    _cardFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 0.75, curve: Curves.easeOut)),
    );
    _bottomFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.7, 1.0, curve: Curves.easeOut)),
    );

    _ctrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = Get.find<AuthState>();
      if (authState.provider.value != LoginType.none) {
        Get.offAllNamed("/map");
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _primaryDark,
              _primary,
              Color(0xFFA8CCFF),
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
                    // 로고
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: const _AppIcon(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 타이틀
                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: const Column(
                          children: [
                            Text(
                              '스토맵',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '지도 위에 당신의 이야기를 남기세요',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // 로그인 카드
                    FadeTransition(
                      opacity: _cardFade,
                      child: SlideTransition(
                        position: _cardSlide,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryDark.withOpacity(0.25),
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
                      ),
                    ),
                    const Spacer(),
                    // 하단 약관 텍스트
                    FadeTransition(
                      opacity: _bottomFade,
                      child: Padding(
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
  const _AppIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2FF),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: SvgPicture.string(
          '''<svg width="60" height="60" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z" fill="#7AB3FF"/>
  <g transform="translate(12, 9)">
    <rect x="-3.5" y="-2.5" width="7" height="5" rx="1" fill="#FF6B6B"/>
    <path d="M -1.5 2.5 L -0.5 3.5 L 0.5 2.5" fill="#FF6B6B"/>
    <rect x="-2.5" y="-1.2" width="5" height="0.6" rx="0.3" fill="white" opacity="0.9"/>
    <rect x="-2.5" y="0.6" width="3.5" height="0.6" rx="0.3" fill="white" opacity="0.9"/>
  </g>
</svg>''',
          width: 62,
          height: 62,
        ),
      ),
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

class _LoginButton extends StatefulWidget {
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
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.75 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: widget.border,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_pressed ? 0.03 : 0.06),
                  blurRadius: _pressed ? 4 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
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
