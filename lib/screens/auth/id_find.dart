import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:unimal/service/auth/authentication_service.dart';
import 'package:unimal/screens/widget/alert/custom_alert.dart';

class IdFindScreen extends StatefulWidget {
  const IdFindScreen({super.key});

  @override
  State<IdFindScreen> createState() => _IdFindScreenState();
}

class _IdFindScreenState extends State<IdFindScreen> {
  final TextEditingController _telController = TextEditingController();
  final TextEditingController _verificationCodeController = TextEditingController();
  final CustomAlert _customAlert = CustomAlert();
  final AuthenticationCodeService _telAuthenticationService = AuthenticationCodeService();
  
  bool _isVerificationSent = false;
  bool _isSendLoading = false;
  bool _isVerifyLoading = false;
  String _sendCodeText = "인증번호 전송";
  String _findEmail = "";
  
  // 타이머 관련 변수
  Timer? _timer;
  int _remainingSeconds = 300; // 5분 = 300초
  bool _isTimerRunning = false;
  
  String _tel = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _telController.dispose();
    _verificationCodeController.dispose();
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

  // 인증번호 전송
  Future<void> _sendVerificationCode() async {
    _tel = _telController.text;
    if (!_isValidPhoneNumber(_tel)) {
      _customAlert.showTextAlert("입력 오류", "올바른 전화번호 형식을 입력해주세요.\n예: 01012345678");
      return;
    }

    setState(() {
      _sendCodeText = "재전송";
      _isSendLoading = true;
    });

    try {
      var authCodeSendCheck = await _telAuthenticationService.sendTelVerificationCode(_tel);    
      if (authCodeSendCheck) {
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
        _customAlert.showTextAlert("전송 실패", "인증번호 전송에 실패했습니다.\n잠시후 다시 시도해주세요.");
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
      var findEmailInfo = await _telAuthenticationService.verifyTelVerificationCodeIdFind(_tel, _verificationCodeController.text);

      setState(() {
        _isVerifyLoading = false;
      });

      // 인증성공 & 아이디 찾기 완료
      if (findEmailInfo.isSuccess) {
        setState(() {
          _isSendLoading = false;
          _findEmail = findEmailInfo.email ?? "";
          // 이메일 찾기 완료 후 타이머 정지
          _isTimerRunning = false;
          _timer?.cancel();
        });
      } else {
        _customAlert.showTextAlert("인증 실패", findEmailInfo.message ?? "아이디 찾기 실패");
      }
      
      
    } catch (error) {
      setState(() {
        _isVerifyLoading = false;
      });
      _customAlert.showTextAlert("인증 실패", "인증번호가 올바르지 않습니다.\n다시 확인해주세요.");
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
          '아이디 찾기',
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
                '전화번호 인증',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '아이디 찾기 서비스 이용을 위해\n전화번호 인증을 진행해주세요.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w300,
                ),
              ),
              SizedBox(height: 40),
              
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isSendLoading || _findEmail.isNotEmpty) ? null : _sendVerificationCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _findEmail.isNotEmpty ? Colors.grey[300] : Colors.white,
                        foregroundColor: _findEmail.isNotEmpty ? Colors.grey[600] : const Color(0xFF4D91FF),
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
                                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF4D91FF)),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        onPressed: (_isVerifyLoading || !_isTimerRunning || _findEmail.isNotEmpty) ? null : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_isTimerRunning && _findEmail.isEmpty) ? Colors.white : Colors.grey[300],
                          foregroundColor: (_isTimerRunning && _findEmail.isEmpty) ? Color(0xFF4D91FF) : Colors.grey[600],
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
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4D91FF)),
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
                SizedBox(height: 50),   
              ],
              if (_findEmail.isNotEmpty) ...[
                SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '찾은 아이디',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        _findEmail,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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