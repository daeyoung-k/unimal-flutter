import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/auth/login/widget/manual_login_form.dart';
import 'package:unimal/service/login/kakao_login_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/service/login/naver_login_service.dart';
import 'package:unimal/service/login/google_login_service.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/theme/app_colors.dart';

class LoginScreens extends StatefulWidget {
  const LoginScreens({super.key});

  @override
  State<LoginScreens> createState() => _LoginScreensState();
}

class _LoginScreensState extends State<LoginScreens>
    with SingleTickerProviderStateMixin {
  bool _showEmailLogin = false;

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
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
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
                  const SizedBox(height: 16),
                  // 타이틀
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: Column(
                        children: [
                          Text(
                            '스토맵',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 31,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '지도위에 남기는 나의 스토리',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
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
                        padding: const EdgeInsets.symmetric(horizontal: 23),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: colors.border),
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow,
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(25, 33, 25, 33),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.97, end: 1.0)
                                      .animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _showEmailLogin
                                ? _EmailLoginSection(
                                    key: const ValueKey('email'),
                                    onBack: () =>
                                        setState(() => _showEmailLogin = false),
                                  )
                                : _SocialLoginSection(
                                    key: const ValueKey('social'),
                                    onEmailLogin: () =>
                                        setState(() => _showEmailLogin = true),
                                  ),
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
                          color: colors.textMuted,
                          fontSize: 11,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w300,
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
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/img/login_logo.svg',
      width: 100,
      height: 120,
    );
  }
}

class _SocialLoginSection extends StatefulWidget {
  final VoidCallback onEmailLogin;

  const _SocialLoginSection({super.key, required this.onEmailLogin});

  @override
  State<_SocialLoginSection> createState() => _SocialLoginSectionState();
}

class _SocialLoginSectionState extends State<_SocialLoginSection> {
  String? _loadingType; // 'kakao' | 'naver' | 'google'

  Future<void> _login(String type, Future<void> Function() loginFn) async {
    if (_loadingType != null) return;
    setState(() => _loadingType = type);
    try {
      await loginFn();
    } finally {
      if (mounted) setState(() => _loadingType = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loadingType != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '시작하기',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontSize: 20,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        _LoginButton(
          onPressed: busy ? null : () => _login('kakao', KakaoLoginService().login),
          backgroundColor: const Color(0xFFFEE500),
          isLoading: _loadingType == 'kakao',
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
          onPressed: busy ? null : () => _login('naver', NaverLoginService().login),
          backgroundColor: const Color(0xFF03C75A),
          isLoading: _loadingType == 'naver',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
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
          onPressed: busy ? null : () => _login('google', GoogleLoginService().login),
          backgroundColor: AppColors.of(context).surface,
          border: Border.all(color: AppColors.of(context).border),
          isLoading: _loadingType == 'google',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/icon/svg/google_icon.svg',
                  width: 22, height: 22),
              const SizedBox(width: 10),
              Text(
                '구글로 시작하기',
                style: TextStyle(
                  color: AppColors.of(context).textPrimary,
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
          onPressed: busy ? null : widget.onEmailLogin,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mail_outline, color: AppColors.of(context).textMuted, size: 18),
              const SizedBox(width: 6),
              Text(
                '이메일로 로그인',
                style: TextStyle(
                  color: AppColors.of(context).textMuted,
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
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Widget child;
  final BoxBorder? border;
  final bool isLoading;

  const _LoginButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.child,
    this.border,
    this.isLoading = false,
  });

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onPressed!();
            },
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: disabled ? 0.55 : (_pressed ? 0.75 : 1.0),
          duration: const Duration(milliseconds: 80),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: widget.border,
              boxShadow: [
                BoxShadow(
                  color: AppColors.of(context).shadow,
                  blurRadius: _pressed ? 4 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.isLoading
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.backgroundColor == Colors.white
                              ? const Color(0xFF4D91FF)
                              : Colors.white,
                        ),
                      ),
                    ),
                  )
                : widget.child,
          ),
        ),
      ),
    );
  }
}

class _EmailLoginSection extends StatelessWidget {
  final VoidCallback onBack;

  const _EmailLoginSection({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ManualLoginFormWidget(onBackPressed: onBack);
  }
}
