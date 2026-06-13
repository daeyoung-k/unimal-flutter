import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:unimal/service/auth/authentication_service.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/utils/custom_alert.dart';

class SignupScreens extends StatefulWidget {
  const SignupScreens({super.key});

  @override
  State<SignupScreens> createState() => _SignupScreensState();
}

class _SignupScreensState extends State<SignupScreens> {
  final UserInfoService _userInfoService = UserInfoService();
  final AuthenticationCodeService _authenticationCodeService =
      AuthenticationCodeService();
  final CustomAlert _customAlert = CustomAlert();

  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emailInputController = TextEditingController();
  final TextEditingController _emailCodeController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  String? _selectedEmailDomain = 'naver.com';
  final List<String> _emailDomains = [
    'naver.com',
    'gmail.com',
    'daum.net',
    'kakao.com',
    'nate.com',
    '직접입력',
  ];

  String _email = '';
  String _nickname = '';
  String _password = '';
  String _passwordCheck = '';

  bool _isSignupLoading = false;

  // 닉네임
  bool _isNicknameVerified = false;

  // 이메일
  bool _isEmailVerificationSent = false;
  bool _isEmailVerified = false;
  bool _isEmailVerificationLoading = false;
  String _emailVerificationCode = '';

  // 타이머
  int _remainingSeconds = 300;
  Timer? _timer;
  bool _isTimerRunning = false;

  // 비밀번호
  bool _isPasswordVerified = false;
  bool _isPasswordCheckVerified = false;

  // ── 비즈니스 로직 ──────────────────────────────────────────────────────────

  void _onNicknameChanged(String value) {
    setState(() {
      if (_isNicknameVerified) _isNicknameVerified = false;
    });
  }

  bool _isValidPassword(String password) {
    return RegExp(
            r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,20}$')
        .hasMatch(password);
  }

  bool _isPasswordMatch() {
    return _passwordController.text == _passwordCheckController.text &&
        _passwordController.text.isNotEmpty;
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _isPasswordVerified = _isValidPassword(value);
      _isPasswordCheckVerified = _isPasswordMatch();
      if (_isPasswordVerified && _isPasswordCheckVerified) {
        _password = value;
        _passwordCheck = _passwordCheckController.text;
      }
    });
  }

  void _onPasswordCheckChanged(String value) {
    setState(() {
      _isPasswordVerified = _isValidPassword(_passwordController.text);
      _isPasswordCheckVerified = _isPasswordMatch();
      if (_isPasswordVerified && _isPasswordCheckVerified) {
        _password = _passwordController.text;
        _passwordCheck = value;
      }
    });
  }

  void _onEmailChanged(String value) {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _isTimerRunning = false;
      _isEmailVerificationSent = false;
      _isEmailVerified = false;
      _emailVerificationCode = '';
      _email = '';
    });
    _emailCodeController.clear();
  }

  bool _canSendEmailVerification() {
    return _emailController.text.isNotEmpty &&
        (_selectedEmailDomain != null && _selectedEmailDomain != '직접입력' ||
            _emailInputController.text.isNotEmpty);
  }

  void _sendEmailVerification() async {
    if (!_canSendEmailVerification()) {
      _customAlert.showSnackBar(context, '이메일을 완성해주세요.');
      return;
    }
    final domain = _selectedEmailDomain == '직접입력'
        ? _emailInputController.text
        : _selectedEmailDomain!;
    _email = '${_emailController.text}@$domain';
    setState(() => _isEmailVerificationLoading = true);
    try {
      final String msg = await _userInfoService.checkEmail(_email);
      if (msg == "ok") {
        if (mounted) {
          setState(() {
            _isEmailVerificationSent = true;
            _isEmailVerificationLoading = false;
          });
          _startTimer();
          _customAlert.showSnackBar(context, '인증번호가 발송되었습니다.', isError: false);
        }
      } else {
        if (mounted) {
          setState(() => _isEmailVerificationLoading = false);
          _customAlert.showSnackBar(context, msg);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEmailVerificationLoading = false);
        _customAlert.showSnackBar(context, '인증번호 발송에 실패했습니다.');
      }
    }
  }

  void _verifyEmailCode() async {
    if (_emailVerificationCode.isEmpty) {
      _customAlert.showSnackBar(context, '인증번호를 입력해주세요.');
      return;
    }
    try {
      final String msg = await _authenticationCodeService
          .verifyEmailVerificationCode(_email, _emailVerificationCode);
      if (msg == "ok") {
        if (mounted) {
          setState(() => _isEmailVerified = true);
          _stopTimer();
          _passwordFocusNode.requestFocus();
          _customAlert.showSnackBar(context, '이메일 인증이 완료되었습니다.',
              isError: false);
        }
      } else {
        if (mounted) _customAlert.showSnackBar(context, msg);
      }
    } catch (e) {
      if (mounted) _customAlert.showSnackBar(context, '인증번호가 올바르지 않습니다.');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = null;
    _remainingSeconds = 300;
    _isTimerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timer != timer) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _isTimerRunning = false;
            _isEmailVerificationSent = false; // 만료 시 재전송 가능하도록 리셋
            _timer?.cancel();
            _timer = null;
            _customAlert.showSnackBar(
                context, '인증 시간이 만료되었습니다. 다시 인증해주세요.');
          }
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _isTimerRunning = false);
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _checkNicknameDuplicate() async {
    final text = _nicknameController.text;
    if (text.length < 3) {
      _customAlert.showSnackBar(context, '닉네임은 3글자 이상 입력해주세요.');
      return;
    }
    if (RegExp(r'^[0-9]+$').hasMatch(text)) {
      _customAlert.showSnackBar(context, '숫자만으로는 닉네임을 만들 수 없습니다.');
      return;
    }
    if (RegExp(r'[ㄱ-ㅎㅏ-ㅣ]').hasMatch(text)) {
      _customAlert.showSnackBar(context, '정상적인 닉네임을 입력해주세요.');
      return;
    }
    _nickname = text;
    final String msg = await _userInfoService.checkNickname(_nickname);
    if (msg == "ok") {
      if (mounted) {
        setState(() => _isNicknameVerified = true);
        _customAlert.showSnackBar(context, '사용 가능한 닉네임입니다.', isError: false);
      }
    } else {
      if (mounted) _customAlert.showSnackBar(context, msg);
    }
  }

  void _signup() async {
    final bool allVerified = _isNicknameVerified &&
        _isEmailVerified &&
        _isPasswordVerified &&
        _isPasswordCheckVerified;
    if (!allVerified) return;
    setState(() => _isSignupLoading = true);
    try {
      final String msg = await _userInfoService.signupV2(
        nickname: _nickname,
        email: _email,
        password: _password,
        checkPassword: _passwordCheck,
      );
      if (!mounted) return;
      if (msg.startsWith('TEL_REQUIRED:')) {
        final signupEmail = msg.substring('TEL_REQUIRED:'.length);
        Get.toNamed('/tel-verification', arguments: {'email': signupEmail});
      } else if (msg == 'ok') {
        _customAlert.pageMovingWithshowTextAlert(
            '회원가입 완료', '회원가입이 완료되었습니다.', '/map');
      } else {
        setState(() => _isSignupLoading = false);
        _customAlert.showSnackBar(context, msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSignupLoading = false);
        _customAlert.showSnackBar(context, '회원가입에 실패했습니다.');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nicknameController.dispose();
    _passwordController.dispose();
    _passwordCheckController.dispose();
    _emailController.dispose();
    _emailInputController.dispose();
    _emailCodeController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // ── 디자인 토큰 ────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF3578E5);
  static const Color _primarySoft = Color(0xFF7AB3FF);
  static const Color _disabledColor = Color(0xFF9CA3AF);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _labelColor = Color(0xFF374151);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _hintColor = Color(0xFFCBD5E1);
  static const Color _helperColor = Color(0xFF9CA3AF);

  // ── UI 헬퍼 ────────────────────────────────────────────────────────────────

  static const Color _errorColor = Color(0xFFEF4444);

  InputDecoration _inputDecoration(String hint,
      {Widget? suffix, bool isError = false, bool isDisabled = false}) {
    final Color borderNormal = isError ? _errorColor : _borderColor;
    final Color borderFocused = isError ? _errorColor : _primary;
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _hintColor,
        fontSize: 15,
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: isDisabled ? const Color(0xFFF1F5F9) : Colors.white,
      suffix: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderNormal, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderFocused, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor, width: 1),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: _labelColor,
            fontFamily: 'Pretendard',
          ),
        ),
      );

  Widget _helperText(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: _helperColor,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w300,
            letterSpacing: 0.96,
          ),
        ),
      );

  // 버튼 색상: completed(인증완료) → soft, active(클릭 가능) → primary, 나머지 → disabled
  Color _btnColor({required bool completed, required bool active}) {
    if (completed) return _primarySoft;
    if (active) return _primary;
    return _disabledColor;
  }

  Widget _sideButton({
    required String label,
    required VoidCallback? onPressed,
    required bool completed,
    required bool active,
    double width = 100,
  }) {
    return SizedBox(
      width: width,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _btnColor(completed: completed, active: active),
          disabledBackgroundColor:
              _btnColor(completed: completed, active: active),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 도메인 드롭다운
  Widget _domainDropdown() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _isEmailVerified ? const Color(0xFFF1F5F9) : Colors.white,
        border: Border.all(color: _borderColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedEmailDomain,
          hint: const Text(
            'naver.com',
            style: TextStyle(
              color: _hintColor,
              fontSize: 15,
              fontFamily: 'Pretendard',
            ),
          ),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: _helperColor),
          style: const TextStyle(
            fontSize: 15,
            fontFamily: 'Pretendard',
            color: _textPrimary,
          ),
          items: _emailDomains
              .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d,
                        style: const TextStyle(
                            fontFamily: 'Pretendard', fontSize: 15)),
                  ))
              .toList(),
          onChanged: _isEmailVerified
              ? null
              : (value) {
                  setState(() {
                    _selectedEmailDomain = value;
                    if (value == '직접입력') {
                      _emailFocusNode.requestFocus();
                    } else if (value != null) {
                      _emailInputController.text = value;
                    }
                  });
                  _onEmailChanged('');
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String nickText = _nicknameController.text;
    final bool nicknameInvalid = nickText.isNotEmpty && (
        nickText.length < 3 ||
        RegExp(r'^[0-9]+$').hasMatch(nickText) ||
        RegExp(r'[ㄱ-ㅎㅏ-ㅣ]').hasMatch(nickText));
    final bool nicknameActive =
        nickText.length >= 3 && !_isNicknameVerified && !nicknameInvalid;
    final bool emailActive =
        _canSendEmailVerification() && !_isEmailVerificationSent && !_isEmailVerified;
    final bool codeActive =
        _isTimerRunning && _emailVerificationCode.length >= 6;
    final bool passwordInvalid =
        _passwordController.text.isNotEmpty && !_isPasswordVerified;
    final bool passwordMismatch =
        _passwordCheckController.text.isNotEmpty && !_isPasswordCheckVerified;
    final bool allVerified = _isNicknameVerified &&
        _isEmailVerified &&
        _isPasswordVerified &&
        _isPasswordCheckVerified;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: _textPrimary, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '회원가입',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
            fontFamily: 'Pretendard',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 닉네임 ───────────────────────────────────────────────────────
            _label('닉네임'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: TextField(
                      controller: _nicknameController,
                      onChanged: _onNicknameChanged,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      style: const TextStyle(
                        fontSize: 15,
                        fontFamily: 'Pretendard',
                        color: _textPrimary,
                      ),
                      decoration: _inputDecoration('3글자 이상',
                          isError: nicknameInvalid),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _sideButton(
                  label: _isNicknameVerified ? '인증완료' : '중복확인',
                  onPressed: nicknameActive ? _checkNicknameDuplicate : null,
                  completed: _isNicknameVerified,
                  active: nicknameActive,
                  width: 100,
                ),
              ],
            ),
            _helperText('숫자만 또는 자음만은 사용 불가'),
            const SizedBox(height: 25),

            // ── 이메일 ───────────────────────────────────────────────────────
            _label('이메일 (아이디)'),
            // 아이디 @ 도메인
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: TextField(
                      controller: _emailController,
                      onChanged: _onEmailChanged,
                      enabled: !_isEmailVerified,
                      style: const TextStyle(
                        fontSize: 15,
                        fontFamily: 'Pretendard',
                        color: _textPrimary,
                      ),
                      decoration: _inputDecoration('이메일',
                          isDisabled: _isEmailVerified),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.alternate_email,
                      color: _helperColor, size: 24),
                ),
                Expanded(
                  child: _selectedEmailDomain == '직접입력'
                      ? SizedBox(
                          height: 56,
                          child: TextField(
                            controller: _emailInputController,
                            focusNode: _emailFocusNode,
                            onChanged: _onEmailChanged,
                            enabled: !_isEmailVerified,
                            style: const TextStyle(
                              fontSize: 15,
                              fontFamily: 'Pretendard',
                              color: _textPrimary,
                            ),
                            decoration: _inputDecoration('도메인 입력',
                                isDisabled: _isEmailVerified),
                          ),
                        )
                      : _domainDropdown(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 인증번호 입력 + 버튼
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: TextField(
                      controller: _emailCodeController,
                      onChanged: (v) =>
                          setState(() => _emailVerificationCode = v),
                      enabled: _isEmailVerificationSent && !_isEmailVerified,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: const TextStyle(
                        fontSize: 15,
                        fontFamily: 'Pretendard',
                        color: _textPrimary,
                      ),
                      decoration: _inputDecoration(
                        '인증번호',
                        isDisabled: !_isEmailVerificationSent || _isEmailVerified,
                        suffix: _isTimerRunning
                            ? Text(
                                _formatTime(_remainingSeconds),
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 13,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // 전송 전: "인증번호 전송" / 전송 후: "확인" / 완료: "인증완료"
                _isEmailVerificationSent && !_isEmailVerified
                    ? _sideButton(
                        label: '확인',
                        onPressed: codeActive ? _verifyEmailCode : null,
                        completed: false,
                        active: codeActive,
                        width: 120,
                      )
                    : _sideButton(
                        label: _isEmailVerified
                            ? '인증완료'
                            : (_isEmailVerificationLoading ? '발송중...' : '인증번호 전송'),
                        onPressed: _isEmailVerified || _isEmailVerificationLoading
                            ? null
                            : (emailActive ? _sendEmailVerification : null),
                        completed: _isEmailVerified,
                        active: emailActive && !_isEmailVerificationLoading,
                        width: 120,
                      ),
              ],
            ),
            const SizedBox(height: 25),

            // ── 비밀번호 ─────────────────────────────────────────────────────
            _label('비밀번호'),
            SizedBox(
              height: 56,
              child: TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: true,
                onChanged: _onPasswordChanged,
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                  color: _textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '비밀번호',
                  hintStyle: const TextStyle(
                    color: _hintColor,
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: _helperColor, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _borderColor, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: passwordInvalid
                          ? const Color(0xFFEF4444)
                          : _borderColor,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: passwordInvalid
                          ? const Color(0xFFEF4444)
                          : _primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 17, vertical: 17),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: TextField(
                controller: _passwordCheckController,
                obscureText: true,
                onChanged: _onPasswordCheckChanged,
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                  color: _textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '비밀번호 확인',
                  hintStyle: const TextStyle(
                    color: _hintColor,
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: _helperColor, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _borderColor, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: passwordMismatch
                          ? const Color(0xFFEF4444)
                          : _borderColor,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: passwordMismatch
                          ? const Color(0xFFEF4444)
                          : _primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 17, vertical: 17),
                ),
              ),
            ),
            _helperText('영어, 숫자, 특수문자 포함 8 ~ 20자'),
            const SizedBox(height: 32),

            // ── 가입하기 ─────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_isSignupLoading || !allVerified) ? null : _signup,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      allVerified && !_isSignupLoading ? _primary : _disabledColor,
                  disabledBackgroundColor: _disabledColor,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSignupLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        '가입하기',
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
