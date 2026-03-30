import 'package:flutter/material.dart';
import 'package:unimal/service/user/model/signup_models.dart';
import 'package:unimal/service/auth/authentication_service.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/utils/custom_alert.dart';
import 'dart:async'; // Timer 사용을 위한 임포트
import 'package:flutter/services.dart'; // TextInputFormatter 사용을 위한 임포트

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

  // 입력 필드 컨트롤러 선언
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _selectedEmailDomain;
  final List<String> _emailDomains = [
    'naver.com',
    'gmail.com',
    'daum.net',
    'kakao.com',
    'nate.com',
    '직접입력'
  ];

  String _email = '';
  String _tel = '';
  String _nickname = '';
  String _password = '';
  String _passwordCheck = '';
  
  // 가입하기 버튼 로딩 상태
  bool _isSignupLoading = false;

  // 닉네임 중복확인 상태
  bool _isNicknameVerified = false;

  // 이메일 인증 관련 상태
  bool _isEmailVerificationSent = false;
  bool _isEmailVerified = false;
  bool _isEmailVerificationLoading = false;
  String _emailVerificationCode = '';

  // 휴대폰 인증 관련 상태
  bool _isPhoneVerificationSent = false;
  bool _isPhoneVerified = false;
  bool _isPhoneVerificationLoading = false;
  String _phoneVerificationCode = '';

  // 타이머 관련 상태
  int _remainingSeconds = 300; // 5분 = 300초
  Timer? _timer;
  bool _isTimerRunning = false;

  // 휴대폰 타이머 관련 상태
  int _phoneRemainingSeconds = 300; // 5분 = 300초
  Timer? _phoneTimer;
  bool _isPhoneTimerRunning = false;

  final TextEditingController _emailInputController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  // 닉네임 입력 필드 변경 감지
  void _onNicknameChanged(String value) {
    if (_isNicknameVerified) {
      setState(() {
        _isNicknameVerified = false;
      });
    }
  }

  bool _isPasswordVerified = false;
  bool _isPasswordCheckVerified = false;

  // 비밀번호 형식 검증 (영어, 숫자, 특수문자 8~20자)
  bool _isValidPassword(String password) {
    return RegExp(
            r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,20}$')
        .hasMatch(password);
  }

  // 비밀번호 확인 검증
  bool _isPasswordMatch() {
    return _passwordController.text == _passwordCheckController.text &&
        _passwordController.text.isNotEmpty;
  }

  // 비밀번호 입력 필드 변경 감지
  void _onPasswordChanged(String value) {
    setState(() {
      // 비밀번호가 변경되면 상태 업데이트
      _isPasswordVerified = _isValidPassword(value);
      _isPasswordCheckVerified = _isPasswordMatch();

      if (_isPasswordVerified && _isPasswordCheckVerified) {
        _password = value;
        _passwordCheck = value;
      }
    });
  }

  // 비밀번호 확인 입력 필드 변경 감지
  void _onPasswordCheckChanged(String value) {
    setState(() {
      // 비밀번호 확인이 변경되면 상태 업데이트
      _isPasswordVerified = _isValidPassword(_passwordController.text);
      _isPasswordCheckVerified = _isPasswordMatch();

      if (_isPasswordVerified && _isPasswordCheckVerified) {
        _password = value;
        _passwordCheck = value;
      }
    });
  }

  // 전화번호 형식 검증
  bool _isValidPhoneNumber(String phone) {
    return RegExp(r'^01[0-9]\d{3,4}\d{4}$').hasMatch(phone);
  }

  // 휴대폰 인증번호 발송
  void _sendPhoneVerification() async {
    if (_phoneController.text.isEmpty) {
      _customAlert.showSnackBar(context, '휴대폰 번호를 입력해주세요.');
      return;
    }

    if (!_isValidPhoneNumber(_phoneController.text)) {
      _customAlert.showSnackBar(context, '올바른 휴대폰 번호 형식을 입력해주세요.');
      return;
    }

    setState(() {
      _isPhoneVerificationLoading = true;
      _tel = _phoneController.text;
    });

    try {
      final String checkTelMessage = await _userInfoService.checkTel(_tel);
      if (checkTelMessage == "ok") {
        if (mounted) {
          setState(() {
            _isPhoneVerificationSent = true;
            _isPhoneVerificationLoading = false;
          });
          _startPhoneTimer(); // 타이머 시작
          _customAlert.showSnackBar(context, '인증번호가 발송되었습니다.', isError: false);
        }
      } else {
        if (mounted) {
          setState(() {
            _isPhoneVerificationLoading = false;
          });
          _customAlert.showSnackBar(context, checkTelMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPhoneVerificationLoading = false;
        });
        _customAlert.showSnackBar(context, '인증번호 발송에 실패했습니다.');
      }
    }
  }

  // 휴대폰 인증번호 확인
  void _verifyPhoneCode() async {
    if (_phoneVerificationCode.isEmpty) {
      _customAlert.showSnackBar(context, '인증번호를 입력해주세요.');
      return;
    }

    try {
      final String verifyTelCodeMessage = await _authenticationCodeService
          .verifyTelVerificationCode(_tel, _phoneVerificationCode);
      if (verifyTelCodeMessage == "ok") {
        if (mounted) {
          setState(() {
            _isPhoneVerified = true;
          });
          _stopPhoneTimer(); // 타이머 정지
          _customAlert.showSnackBar(context, '휴대폰 인증이 완료되었습니다.',
              isError: false);
        }
      } else {
        if (mounted) {
          _customAlert.showSnackBar(context, verifyTelCodeMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        _customAlert.showSnackBar(context, '인증번호가 올바르지 않습니다.');
      }
    }
  }

  // 이메일 입력 감지
  void _onEmailChanged(String value) {
    setState(() {
      // 이메일이 변경되면 인증 상태 초기화
      _isEmailVerificationSent = false;
      _isEmailVerified = false;
      _emailVerificationCode = '';
      _email = '';
    });
  }

  // 이메일 인증하기 버튼 활성화 조건 확인
  bool _canSendEmailVerification() {
    return _emailController.text.isNotEmpty &&
        (_selectedEmailDomain != null && _selectedEmailDomain != '직접입력' ||
            _emailInputController.text.isNotEmpty);
  }

  // 이메일 인증하기
  void _sendEmailVerification() async {
    if (!_canSendEmailVerification()) {
      _customAlert.showSnackBar(context, '이메일을 완성해주세요.');
      return;
    }

    // 이메일 주소 조합
    _email = _emailController.text +
        '@' +
        (_selectedEmailDomain == '직접입력'
            ? _emailInputController.text
            : _selectedEmailDomain!);

    setState(() {
      _isEmailVerificationLoading = true;
    });

    try {
      final String checkEmailMessage =
          await _userInfoService.checkEmail(_email);
      if (checkEmailMessage == "ok") {
        if (mounted) {
          setState(() {
            _isEmailVerificationSent = true;
            _isEmailVerificationLoading = false;
          });
          _startTimer(); // 타이머 시작
          _customAlert.showSnackBar(context, '인증번호가 발송되었습니다.', isError: false);
        }
      } else {
        if (mounted) {
          setState(() {
            _isEmailVerificationLoading = false;
          });
          _customAlert.showSnackBar(context, checkEmailMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEmailVerificationLoading = false;
        });
        _customAlert.showSnackBar(context, '인증번호 발송에 실패했습니다.');
      }
    }
  }

  // 이메일 인증번호 확인
  void _verifyEmailCode() async {
    if (_emailVerificationCode.isEmpty) {
      _customAlert.showSnackBar(context, '인증번호를 입력해주세요.');
      return;
    }

    try {
      final String verifyEmailCodeMessage = await _authenticationCodeService
          .verifyEmailVerificationCode(_email, _emailVerificationCode);
      if (verifyEmailCodeMessage == "ok") {
        if (mounted) {
          setState(() {
            _isEmailVerified = true;
          });
          _stopTimer();
          _customAlert.showSnackBar(context, '이메일 인증이 완료되었습니다.',
              isError: false);
        }
      } else {
        if (mounted) {
          _customAlert.showSnackBar(context, verifyEmailCodeMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        _customAlert.showSnackBar(context, '인증번호가 올바르지 않습니다.');
      }
    }
  }

  // 타이머 시작
  void _startTimer() {
    // 기존 타이머가 있으면 취소 후 참조 해제
    _timer?.cancel();
    _timer = null;

    _remainingSeconds = 300; // 5분으로 리셋
    _isTimerRunning = true;

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      // 다른 타이머가 이미 시작되어 이 타이머가 취소된 경우 즉시 종료
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
            _timer?.cancel();
            _timer = null;
            _customAlert.showSnackBar(context, '인증 시간이 만료되었습니다. 다시 인증해주세요.');
          }
        });
      }
    });
  }

  // 타이머 정지
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    if (mounted) {
      setState(() {
        _isTimerRunning = false;
      });
    }
  }

  // 휴대폰 타이머 시작
  void _startPhoneTimer() {
    // 기존 휴대폰 타이머가 있으면 취소 후 참조 해제
    _phoneTimer?.cancel();
    _phoneTimer = null;

    _phoneRemainingSeconds = 300; // 5분으로 리셋
    _isPhoneTimerRunning = true;

    _phoneTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      // 다른 타이머가 이미 시작되어 이 타이머가 취소된 경우 즉시 종료
      if (_phoneTimer != timer) {
        timer.cancel();
        return;
      }

      if (mounted) {
        setState(() {
          if (_phoneRemainingSeconds > 0) {
            _phoneRemainingSeconds--;
          } else {
            _isPhoneTimerRunning = false;
            _phoneTimer?.cancel();
            _phoneTimer = null;
            _customAlert.showSnackBar(context, '인증 시간이 만료되었습니다. 다시 인증해주세요.');
          }
        });
      }
    });
  }

  // 휴대폰 타이머 정지
  void _stopPhoneTimer() {
    _phoneTimer?.cancel();
    _phoneTimer = null;
    if (mounted) {
      setState(() {
        _isPhoneTimerRunning = false;
      });
    }
  }

  // 타이머 시간 포맷팅
  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // 중복확인 함수
  void _checkNicknameDuplicate() async {
    // 3글자 이상 검사
    if (_nicknameController.text.length < 3) {
      if (mounted) {
        _customAlert.showSnackBar(context, '닉네임은 3글자 이상 입력해주세요.');
      }
      return;
    }

    // 숫자만 있는 경우 검사
    if (RegExp(r'^[0-9]+$').hasMatch(_nicknameController.text)) {
      if (mounted) {
        _customAlert.showSnackBar(context, '숫자만으로는 닉네임을 만들 수 없습니다.');
      }
      return;
    }

    // 자음만 있는 경우 검사
    if (RegExp(r'^[ㅏㅑㅓㅕㅗㅛㅜㅠㅡㅣㅐㅒㅔㅖㅘㅙㅚㅝㅞㅟㅢㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ]+$')
        .hasMatch(_nicknameController.text)) {
      if (mounted) {
        _customAlert.showSnackBar(context, '정상적인 닉네임을 입력해주세요.');
      }
      return;
    }

    _nickname = _nicknameController.text;
    final String checkNicknameMessage =
        await _userInfoService.checkNickname(_nickname);

    if (checkNicknameMessage == "ok") {
      if (mounted) {
        setState(() {
          _isNicknameVerified = true;
        });
        _customAlert.showSnackBar(context, '사용 가능한 닉네임입니다.', isError: false);
      }
    } else {
      if (mounted) {
        _customAlert.showSnackBar(context, checkNicknameMessage);
      }
      return;
    }
  }

  void _signup() async {
    if (_isNicknameVerified && _isEmailVerified && _isPhoneVerified && _isPasswordVerified && _isPasswordCheckVerified) {
      setState(() {
        _isSignupLoading = true;
      });
      
      try {
        final String signupMessage = await _userInfoService.signup(
          SignupModel(
            nickname: _nickname,
            email: _email,
            tel: _tel,
            password: _password,
            checkPassword: _passwordCheck,
          )
        );
        if (signupMessage == "ok") {
          if (mounted) {
            _customAlert.pageMovingWithshowTextAlert('회원가입 완료', '회원가입이 완료되었습니다.', '/login');
          }
        } else {
          if (mounted) {
            setState(() {
              _isSignupLoading = false;
            });
            _customAlert.showSnackBar(context, signupMessage);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSignupLoading = false;
          });
          _customAlert.showSnackBar(context, '회원가입에 실패했습니다.');
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneTimer?.cancel();
    super.dispose();
  }

  static const Color _primary = Color(0xFF4D91FF);
  static const Color _primaryDark = Color(0xFF3578E5);
  static const Color _fieldBg = Color(0xFFF3F4F6);
  static const Color _labelColor = Color(0xFF374151);
  static const Color _hintColor = Color(0xFF9CA3AF);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _errorColor = Color(0xFFEF4444);

  InputDecoration _fieldDecoration(String hint, {IconData? prefixIcon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintColor, fontSize: 15, fontFamily: 'Pretendard'),
      filled: true,
      fillColor: _fieldBg,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: _hintColor, size: 20) : null,
      suffix: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _labelColor, fontFamily: 'Pretendard')),
  );

  Widget _successText(String text) => Row(
    children: [
      const Icon(Icons.check_circle_rounded, color: _successColor, size: 14),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 12, color: _successColor, fontFamily: 'Pretendard', fontWeight: FontWeight.w500)),
    ],
  );

  Widget _errorText(String text) => Text(text, style: const TextStyle(fontSize: 12, color: _errorColor, fontFamily: 'Pretendard'));
  Widget _infoText(String text) => Text(text, style: const TextStyle(fontSize: 12, color: _hintColor, fontFamily: 'Pretendard'));

  Widget _actionButton({required String label, required VoidCallback? onPressed, bool confirmed = false}) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: confirmed ? _successColor : (onPressed != null ? _primary : _hintColor.withOpacity(0.3)),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontSize: 14, fontFamily: 'Pretendard', fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allVerified = _isNicknameVerified && _isEmailVerified && _isPhoneVerified && _isPasswordVerified && _isPasswordCheckVerified;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_primaryDark, _primary, Color(0xFFA8CCFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 앱바
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        '회원가입',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Pretendard', fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // 폼 카드
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryDark.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── 닉네임 ──────────────────────────────────────
                        _label('닉네임'),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nicknameController,
                                onChanged: _onNicknameChanged,
                                style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: _labelColor),
                                decoration: _fieldDecoration('닉네임 (3글자 이상)'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _actionButton(
                              label: _isNicknameVerified ? '✓ 확인됨' : '중복확인',
                              onPressed: _isNicknameVerified ? null : _checkNicknameDuplicate,
                              confirmed: _isNicknameVerified,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_isNicknameVerified)
                          _successText('사용 가능한 닉네임입니다')
                        else
                          _infoText('3글자 이상, 숫자만 또는 자음만은 사용 불가'),
                        const SizedBox(height: 20),

                        // ── 이메일 ──────────────────────────────────────
                        _label('이메일 (아이디)'),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _emailController,
                                onChanged: _onEmailChanged,
                                style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: _labelColor),
                                decoration: _fieldDecoration('이메일', prefixIcon: Icons.mail_outline_rounded),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _actionButton(
                              label: _isEmailVerified ? '✓ 확인됨' : (_isEmailVerificationLoading ? '발송중...' : (_isEmailVerificationSent ? '재전송' : '인증하기')),
                              onPressed: _isEmailVerified ? null : (_isEmailVerificationLoading ? null : (_canSendEmailVerification() ? _sendEmailVerification : null)),
                              confirmed: _isEmailVerified,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // @ 도메인
                        Row(
                          children: [
                            const Text('@', style: TextStyle(fontSize: 15, color: _labelColor, fontFamily: 'Pretendard', fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _selectedEmailDomain == '직접입력'
                                  ? Row(children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _emailInputController,
                                          focusNode: _emailFocusNode,
                                          onChanged: _onEmailChanged,
                                          style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: _labelColor),
                                          decoration: _fieldDecoration('도메인 입력'),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      PopupMenuButton<String>(
                                        onSelected: (value) => setState(() { _emailInputController.text = value; }),
                                        itemBuilder: (context) => _emailDomains
                                            .where((d) => d != '직접입력')
                                            .map((d) => PopupMenuItem(value: d, child: Text(d, style: const TextStyle(fontFamily: 'Pretendard'))))
                                            .toList(),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: _fieldBg, borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.arrow_drop_down, color: _hintColor),
                                        ),
                                      ),
                                    ])
                                  : DropdownButtonFormField<String>(
                                      value: _selectedEmailDomain,
                                      items: _emailDomains.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontFamily: 'Pretendard', fontSize: 14)))).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedEmailDomain = value;
                                          if (value == '직접입력') _emailFocusNode.requestFocus();
                                          else if (value != null) _emailInputController.text = value;
                                        });
                                        _onEmailChanged('');
                                      },
                                      decoration: InputDecoration(
                                        filled: true, fillColor: _fieldBg,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        if (_isEmailVerificationSent && !_isEmailVerified) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (v) => setState(() => _emailVerificationCode = v),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                                  style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: _labelColor),
                                  decoration: _fieldDecoration('인증번호 6자리',
                                    suffix: _isTimerRunning
                                        ? Text(_formatTime(_remainingSeconds), style: const TextStyle(color: _primary, fontSize: 13, fontFamily: 'Pretendard', fontWeight: FontWeight.w600))
                                        : null),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _actionButton(
                                label: '확인',
                                onPressed: (_isTimerRunning && _emailVerificationCode.length >= 6) ? _verifyEmailCode : null,
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        if (_isEmailVerified)
                          _successText('이메일 인증 완료')
                        else if (_isEmailVerificationSent)
                          _infoText('이메일로 발송된 인증번호를 입력하세요'),
                        const SizedBox(height: 20),

                        // ── 비밀번호 ────────────────────────────────────
                        _label('비밀번호'),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          onChanged: _onPasswordChanged,
                          style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: _labelColor),
                          decoration: _fieldDecoration('비밀번호',
                            prefixIcon: Icons.lock_outline_rounded,
                            suffix: _passwordController.text.isNotEmpty
                                ? Icon(_isPasswordVerified ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    color: _isPasswordVerified ? _successColor : _errorColor, size: 18)
                                : null),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordCheckController,
                          obscureText: true,
                          onChanged: _onPasswordCheckChanged,
                          style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: _labelColor),
                          decoration: _fieldDecoration('비밀번호 확인',
                            prefixIcon: Icons.lock_outline_rounded,
                            suffix: _passwordCheckController.text.isNotEmpty
                                ? Icon(_isPasswordCheckVerified ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    color: _isPasswordCheckVerified ? _successColor : _errorColor, size: 18)
                                : null),
                        ),
                        const SizedBox(height: 6),
                        if (_passwordController.text.isNotEmpty && _isPasswordVerified && _isPasswordCheckVerified)
                          _successText('비밀번호가 일치합니다')
                        else if (_passwordController.text.isNotEmpty && !_isPasswordVerified)
                          _errorText('영어, 숫자, 특수문자 포함 8~20자')
                        else if (_passwordCheckController.text.isNotEmpty && !_isPasswordCheckVerified)
                          _errorText('비밀번호가 일치하지 않습니다')
                        else
                          _infoText('영어, 숫자, 특수문자 포함 8~20자'),
                        const SizedBox(height: 20),

                        // ── 휴대폰 번호 ─────────────────────────────────
                        _label('휴대폰 번호'),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                                style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: _labelColor),
                                decoration: _fieldDecoration('숫자만 입력', prefixIcon: Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _actionButton(
                              label: _isPhoneVerified ? '✓ 확인됨' : (_isPhoneVerificationLoading ? '발송중...' : (_isPhoneVerificationSent ? '재전송' : '인증번호 받기')),
                              onPressed: _isPhoneVerified ? null : (_isPhoneVerificationLoading ? null : _sendPhoneVerification),
                              confirmed: _isPhoneVerified,
                            ),
                          ],
                        ),
                        if (_isPhoneVerificationSent && !_isPhoneVerified) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (v) => setState(() => _phoneVerificationCode = v),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                                  style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: _labelColor),
                                  decoration: _fieldDecoration('인증번호 6자리',
                                    suffix: _isPhoneTimerRunning
                                        ? Text(_formatTime(_phoneRemainingSeconds), style: const TextStyle(color: _primary, fontSize: 13, fontFamily: 'Pretendard', fontWeight: FontWeight.w600))
                                        : null),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _actionButton(
                                label: '확인',
                                onPressed: (_isPhoneTimerRunning && _phoneVerificationCode.length >= 6) ? _verifyPhoneCode : null,
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        if (_isPhoneVerified)
                          _successText('휴대폰 인증 완료')
                        else if (_isPhoneVerificationSent)
                          _infoText('문자로 발송된 인증번호를 입력하세요'),
                        const SizedBox(height: 28),

                        // ── 가입하기 ────────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (_isSignupLoading || !allVerified) ? null : _signup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: allVerified && !_isSignupLoading ? _primary : _hintColor.withOpacity(0.3),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: _isSignupLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('가입하기', style: TextStyle(fontSize: 16, fontFamily: 'Pretendard', fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
