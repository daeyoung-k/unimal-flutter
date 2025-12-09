import 'package:flutter/material.dart';
import 'package:unimal/models/signup_models.dart';
import 'package:unimal/service/auth/authentication_service.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/screens/widget/alert/custom_alert.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4D91FF),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '회원가입',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 닉네임
                const Text('닉네임',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    )),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nicknameController,
                        onChanged: _onNicknameChanged,
                        decoration: InputDecoration(
                          hintText: '닉네임',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isNicknameVerified
                            ? null
                            : _checkNicknameDuplicate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isNicknameVerified ? Colors.green : Colors.white,
                          foregroundColor: _isNicknameVerified
                              ? Colors.white
                              : const Color(0xFF4D91FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isNicknameVerified ? '✓ 확인됨' : '중복확인',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_isNicknameVerified)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          '닉네임 확인 완료',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    '3글자 이상 입력',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                const SizedBox(height: 20),

                // 아이디
                const Text('이메일 (아이디)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    )),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이메일 입력란과 인증하기 버튼
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            onChanged: _onEmailChanged,
                            decoration: InputDecoration(
                              hintText: '이메일',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isEmailVerified
                                ? null
                                : (_isEmailVerificationLoading
                                    ? null
                                    : (_canSendEmailVerification()
                                        ? _sendEmailVerification
                                        : null)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEmailVerified
                                  ? Colors.green
                                  : Colors.white,
                              foregroundColor: _isEmailVerified
                                  ? Colors.white
                                  : const Color(0xFF4D91FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isEmailVerified
                                ? const Text(
                                    '✓ 확인됨',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : _isEmailVerificationLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  const Color(0xFF4D91FF)),
                                        ),
                                      )
                                    : Text(
                                        _isEmailVerificationSent
                                            ? '재전송'
                                            : '인증하기',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 골뱅이와 도메인 부분
                    Row(
                      children: [
                        const Text('@',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontFamily: 'Pretendard',
                            )),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _selectedEmailDomain == '직접입력'
                                    ? TextField(
                                        controller: _emailInputController,
                                        focusNode: _emailFocusNode,
                                        onChanged: _onEmailChanged,
                                        decoration: InputDecoration(
                                          hintText: '도메인 입력',
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 12),
                                        ),
                                      )
                                    : DropdownButtonFormField<String>(
                                        value: _selectedEmailDomain,
                                        items: _emailDomains
                                            .map((domain) => DropdownMenuItem(
                                                  value: domain,
                                                  child: Text(
                                                    domain,
                                                    style: const TextStyle(
                                                      fontFamily: 'Pretendard',
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedEmailDomain = value;
                                            if (value == '직접입력') {
                                              _emailFocusNode.requestFocus();
                                            } else if (value != null) {
                                              _emailInputController.text =
                                                  value;
                                            }
                                          });
                                          _onEmailChanged(
                                              ''); // 도메인 변경 시 이메일 입력 감지
                                        },
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 12),
                                        ),
                                      ),
                              ),
                              if (_selectedEmailDomain == '직접입력')
                                Container(
                                  margin: const EdgeInsets.only(left: 5),
                                  child: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      setState(() {
                                        if (value != '직접입력') {
                                          _emailInputController.text = value;
                                        }
                                      });
                                    },
                                    itemBuilder: (context) => _emailDomains
                                        .where((domain) => domain != '직접입력')
                                        .map((domain) => PopupMenuItem(
                                              value: domain,
                                              child: Text(
                                                domain,
                                                style: const TextStyle(
                                                  fontFamily: 'Pretendard',
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // 인증번호 입력란 (인증 발송 후에만 표시)
                if (_isEmailVerificationSent && !_isEmailVerified)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [                      
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) {
                                setState(() {
                                  _emailVerificationCode = value;
                                });
                              },
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: InputDecoration(
                                hintText: '인증번호 6자리',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                suffix: _isTimerRunning
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(right: 12),
                                        child: Text(
                                          _formatTime(_remainingSeconds),
                                          style: const TextStyle(
                                            color: Color(0xFF4D91FF),
                                            fontSize: 14,
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (_isTimerRunning &&
                                      _emailVerificationCode.length >= 6)
                                  ? _verifyEmailCode
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_isTimerRunning &&
                                        _emailVerificationCode.length >= 6)
                                    ? Colors.white
                                    : Colors.grey[300],
                                foregroundColor: (_isTimerRunning &&
                                        _emailVerificationCode.length >= 6)
                                    ? const Color(0xFF4D91FF)
                                    : Colors.grey[600],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                '확인',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                // 인증 완료 표시
                if (_isEmailVerified)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              '이메일 인증 완료',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // 비밀번호
                const Text('비밀번호',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onChanged: _onPasswordChanged,
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    suffixIcon: _passwordController.text.isNotEmpty
                        ? Icon(
                            _isPasswordVerified
                                ? Icons.check_circle
                                : Icons.error,
                            color:
                                _isPasswordVerified ? Colors.green : Colors.red,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordCheckController,
                  obscureText: true,
                  onChanged: _onPasswordCheckChanged,
                  decoration: InputDecoration(
                    hintText: '비밀번호 확인',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    suffixIcon: _passwordCheckController.text.isNotEmpty
                        ? Icon(
                            _isPasswordCheckVerified
                                ? Icons.check_circle
                                : Icons.error,
                            color: _isPasswordCheckVerified
                                ? Colors.green
                                : Colors.red,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                if (_passwordController.text.isNotEmpty && _isPasswordVerified)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          '올바른 비밀번호 형식입니다',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_passwordController.text.isNotEmpty &&
                    !_isPasswordVerified)
                  Text(
                    '영어, 숫자, 특수문자를 포함하여 8~20자로 입력해주세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                    ),
                  )
                else
                  Text(
                    '영어, 숫자, 특수문자를 포함하여 8~20자로 입력해주세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                const SizedBox(height: 4),
                if (_passwordCheckController.text.isNotEmpty)
                  _isPasswordCheckVerified
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text(
                                '비밀번호가 일치합니다',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          '비밀번호가 일치하지 않습니다',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                const SizedBox(height: 20),

                // 휴대폰 번호
                const Text('휴대폰 번호',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    )),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: InputDecoration(
                          hintText: '휴대폰 번호',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isPhoneVerified
                            ? null
                            : (_isPhoneVerificationLoading
                                ? null
                                : _sendPhoneVerification),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isPhoneVerified ? Colors.green : Colors.white,
                          foregroundColor: _isPhoneVerified
                              ? Colors.white
                              : const Color(0xFF4D91FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isPhoneVerified
                            ? const Text(
                                '✓ 확인됨',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : _isPhoneVerificationLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          const Color(0xFF4D91FF)),
                                    ),
                                  )
                                : Text(
                                    _isPhoneVerificationSent
                                        ? '재전송'
                                        : '인증번호 받기',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                      ),
                    ),
                  ],
                ),
                // 휴대폰 인증번호 입력란 (인증 발송 후에만 표시)
                if (_isPhoneVerificationSent && !_isPhoneVerified)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [                      
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) {
                                setState(() {
                                  _phoneVerificationCode = value;
                                });
                              },
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: InputDecoration(
                                hintText: '인증번호 6자리',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                suffix: _isPhoneTimerRunning
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(right: 12),
                                        child: Text(
                                          _formatTime(_phoneRemainingSeconds),
                                          style: const TextStyle(
                                            color: Color(0xFF4D91FF),
                                            fontSize: 14,
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (_isPhoneTimerRunning &&
                                      _phoneVerificationCode.length >= 6)
                                  ? _verifyPhoneCode
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_isPhoneTimerRunning &&
                                        _phoneVerificationCode.length >= 6)
                                    ? Colors.white
                                    : Colors.grey[300],
                                foregroundColor: (_isPhoneTimerRunning &&
                                        _phoneVerificationCode.length >= 6)
                                    ? const Color(0xFF4D91FF)
                                    : Colors.grey[600],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                '확인',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                // 휴대폰 인증 완료 표시
                if (_isPhoneVerified)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              '휴대폰 인증 완료',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),

                // 가입하기 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isSignupLoading ||
                            !(_isNicknameVerified &&
                                _isEmailVerified &&
                                _isPhoneVerified &&
                                _isPasswordVerified &&
                                _isPasswordCheckVerified))
                        ? null
                        : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_isNicknameVerified &&
                              _isEmailVerified &&
                              _isPhoneVerified &&
                              _isPasswordVerified &&
                              _isPasswordCheckVerified &&
                              !_isSignupLoading)
                          ? Colors.white
                          : Colors.grey[300],
                      foregroundColor: (_isNicknameVerified &&
                              _isEmailVerified &&
                              _isPhoneVerified &&
                              _isPasswordVerified &&
                              _isPasswordCheckVerified &&
                              !_isSignupLoading)
                          ? const Color(0xFF4D91FF)
                          : Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSignupLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  const Color(0xFF4D91FF)),
                            ),
                          )
                        : Text(
                            '가입하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
