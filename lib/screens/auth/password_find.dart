import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:unimal/service/auth/authentication_service.dart';
import 'package:unimal/screens/widget/alert/custom_alert.dart';
import 'package:unimal/service/user/user_info_service.dart';

class PasswordFindScreen extends StatefulWidget {
  const PasswordFindScreen({super.key});

  @override
  State<PasswordFindScreen> createState() => _PasswordFindScreenState();
}

class _PasswordFindScreenState extends State<PasswordFindScreen> {
  final TextEditingController _telController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _verificationCodeController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final CustomAlert _customAlert = CustomAlert();
  final AuthenticationCodeService _telAuthenticationService =
      AuthenticationCodeService();

  bool _isVerificationSent = false;
  bool _isSendLoading = false;
  bool _isVerifyLoading = false;
  bool _isVerificationCompleted = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _sendCodeText = "인증번호 전송";

  // 타이머 관련 변수
  Timer? _timer;
  int _remainingSeconds = 300; // 5분 = 300초
  bool _isTimerRunning = false;

  String _email = "";
  String _tel = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _telController.dispose();
    _emailController.dispose();
    _verificationCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // 타이머 시작
  void _startTimer() {
    _remainingSeconds = 300; // 5분으로 리셋
    _isTimerRunning = true;

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _isTimerRunning = false;
          timer.cancel();
        }
      });
    });
  }

  // 남은 시간을 MM:SS 형식으로 변환
  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // 전화번호 형식 검증
  bool _isValidPhoneNumber(String phone) {
    return RegExp(r'^01[0-9]\d{3,4}\d{4}$').hasMatch(phone);
  }

  // 이메일 형식 검증
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  // 비밀번호 형식 검증 (영어, 숫자, 특수문자 8~20자)
  bool _isValidPassword(String password) {
    return RegExp(
            r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,20}$')
        .hasMatch(password);
  }

  // 인증번호 전송
  Future<void> _sendVerificationCode() async {
    _email = _emailController.text;
    _tel = _telController.text;

    if (!_isValidEmail(_email)) {
      _customAlert.showTextAlert(
          "입력 오류", "올바른 이메일 형식을 입력해주세요.\n예: user@example.com");
      return;
    }

    if (!_isValidPhoneNumber(_tel)) {
      _customAlert.showTextAlert(
          "입력 오류", "올바른 전화번호 형식을 입력해주세요.\n예: 01012345678");
      return;
    }

    setState(() {
      _sendCodeText = "재전송";
      _isSendLoading = true;
    });

    try {
      var authCodeSendCheckMessage = await _telAuthenticationService
          .sendEmailTelCheckVerificationCode(_email, _tel);
      if (authCodeSendCheckMessage == "ok") {
        setState(() {
          _isVerificationSent = true;
          _isSendLoading = false;
        });

        _startTimer(); // 타이머 시작
        _customAlert.showTextAlert("인증번호 전송", "인증번호가 전송되었습니다.");
      } else {
        setState(() {
          _isSendLoading = false;
        });
        _customAlert.showTextAlert("전송 실패", authCodeSendCheckMessage);
      }
    } catch (error) {
      setState(() {
        _isSendLoading = false;
      });
      _customAlert.showTextAlert("전송 실패", "인증번호 전송에 실패했습니다.\n잠시후 다시 시도해주세요.");
    }
  }

  // 인증번호 확인
  Future<void> _verifyCode() async {
    if (_verificationCodeController.text.isEmpty) {
      _customAlert.showTextAlert("입력 오류", "인증번호를 입력해주세요.");
      return;
    }

    if (_verificationCodeController.text.length != 6) {
      _customAlert.showTextAlert("입력 오류", "인증번호는 6자리로 입력해주세요.");
      return;
    }

    setState(() {
      _isVerifyLoading = true;
    });

    try {
      var verifyCheckMessage =
          await _telAuthenticationService.verifyEmailTelVerificationCode(
              _email, _tel, _verificationCodeController.text);
      // 인증성공 & 로그인 완료 처리
      if (verifyCheckMessage == "ok") {
        setState(() {
          _isVerifyLoading = false;
          _isVerificationCompleted = true;
        });
        _customAlert.showTextAlert("인증 성공", "인증이 완료되었습니다.\n새 비밀번호를 입력해주세요.");
      } else {
        setState(() {
          _isVerifyLoading = false;
        });
        _customAlert.showTextAlert("인증 실패", verifyCheckMessage);
      }
    } catch (error) {
      setState(() {
        _isVerifyLoading = false;
      });
      _customAlert.showTextAlert("인증 실패", "인증번호가 올바르지 않습니다.\n다시 확인해주세요.");
    }
  }

  // 비밀번호 변경
  Future<void> _changePassword() async {
    String password = _passwordController.text;
    String confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty) {
      _customAlert.showTextAlert("입력 오류", "비밀번호를 입력해주세요.");
      return;
    }

    if (!_isValidPassword(password)) {
      _customAlert.showTextAlert(
          "입력 오류", "비밀번호는 영어, 숫자, 특수문자를 포함하여\n8~20자로 입력해주세요.");
      return;
    }

    if (confirmPassword.isEmpty) {
      _customAlert.showTextAlert("입력 오류", "비밀번호 확인을 입력해주세요.");
      return;
    }

    if (password != confirmPassword) {
      _customAlert.showTextAlert("입력 오류", "비밀번호가 일치하지 않습니다.");
      return;
    }
    var userInfoService = UserInfoService();

    var changePasswordMessage =
        await userInfoService.changePassword(_email, password, confirmPassword);

      if (changePasswordMessage == "ok") {
        _customAlert.pageMovingWithshowTextAlert("비밀번호 변경", "비밀번호가 성공적으로 변경되었습니다.", "/login");      
      } else {
        _customAlert.showTextAlert("비밀번호 변경 실패", changePasswordMessage);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4D91FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          '비밀번호 찾기',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                _isVerificationCompleted ? '새 비밀번호 설정' : '전화번호 인증',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                _isVerificationCompleted
                    ? '새로운 비밀번호를 입력해주세요.'
                    : '비밀번호 찾기 서비스 이용을 위해\n전화번호 인증을 진행해주세요.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w300,
                ),
              ),
              SizedBox(height: 40),
              if (!_isVerificationCompleted) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: '이메일 (아이디)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(height: 10),

                // 전화번호 입력
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _telController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: InputDecoration(
                          hintText: '전화번호',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_isSendLoading || _isVerificationCompleted)
                            ? null
                            : _sendVerificationCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isVerificationCompleted
                              ? Colors.grey[300]
                              : Colors.white,
                          foregroundColor: _isVerificationCompleted
                              ? Colors.grey[600]
                              : const Color(0xFF4D91FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSendLoading
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
                                _sendCodeText,
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
                SizedBox(height: 5),

                if (_isVerificationSent) ...[
                  SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _verificationCodeController,
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
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            suffix: _isTimerRunning
                                ? Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: Text(
                                      _formatTime(_remainingSeconds),
                                      style: TextStyle(
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
                      SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_isVerifyLoading ||
                                  !_isTimerRunning ||
                                  _isVerificationCompleted)
                              ? null
                              : _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (_isTimerRunning && !_isVerificationCompleted)
                                    ? Colors.white
                                    : Colors.grey[300],
                            foregroundColor:
                                (_isTimerRunning && !_isVerificationCompleted)
                                    ? Color(0xFF4D91FF)
                                    : Colors.grey[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isVerifyLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF4D91FF)),
                                  ),
                                )
                              : Text(
                                  '인증하기',
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
                  SizedBox(height: 15),
                ],
              ] else ...[
                // 비밀번호 변경 UI
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: '새 비밀번호',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    hintText: '새 비밀번호 확인',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4D91FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      '비밀번호 변경',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 15),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '• 영어, 숫자, 특수문자를 포함하여 8~20자로 입력해주세요\n• 비밀번호 확인란과 일치해야 합니다',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
