import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:unimal/service/auth/authentication_service.dart';
import 'package:unimal/utils/custom_alert.dart';

class TelVerificationScreen extends StatefulWidget {
  const TelVerificationScreen({super.key});

  @override
  State<TelVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<TelVerificationScreen> {
  final TextEditingController _telController = TextEditingController();
  final TextEditingController _verificationCodeController = TextEditingController();
  final CustomAlert _customAlert = CustomAlert();
  final AuthenticationCodeService _telAuthenticationService = AuthenticationCodeService();

  bool _isVerificationSent = false;
  bool _isSendLoading = false;
  bool _isVerifyLoading = false;
  String _sendCodeText = "인증번호 전송";

  Timer? _timer;
  int _remainingSeconds = 300;
  bool _isTimerRunning = false;

  String _email = "";
  String _tel = "";

  static const Color _primary = Color(0xFF4D91FF);
  static const Color _primaryDark = Color(0xFF3578E5);
  static const Color _fieldBg = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      _email = arguments['email'] as String;
    }
  }

  @override
  void dispose() {
    _telController.dispose();
    _verificationCodeController.dispose();
    _timer?.cancel();
    super.dispose();
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
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _isTimerRunning = false;
          _timer?.cancel();
          _timer = null;
        }
      });
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  bool _isValidPhoneNumber(String phone) {
    return RegExp(r'^01[0-9]\d{3,4}\d{4}$').hasMatch(phone);
  }

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
      var authCodeSendCheck = await _telAuthenticationService.sendEmailTelVerificationCode(_email, _tel);
      if (authCodeSendCheck) {
        setState(() {
          _isVerificationSent = true;
          _isSendLoading = false;
        });
        _startTimer();
        _customAlert.showTextAlert("인증번호 전송", "인증번호가 전송되었습니다.");
      } else {
        setState(() { _isSendLoading = false; });
        _customAlert.showTextAlert("전송 실패", "인증번호 전송에 실패했습니다.\n잠시후 다시 시도해주세요.");
      }
    } catch (error) {
      setState(() { _isSendLoading = false; });
      _customAlert.showTextAlert("전송 실패", "인증번호 전송에 실패했습니다.\n잠시후 다시 시도해주세요.");
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationCodeController.text.isEmpty) {
      _customAlert.showTextAlert("입력 오류", "인증번호를 입력해주세요.");
      return;
    }
    if (_verificationCodeController.text.length != 6) {
      _customAlert.showTextAlert("입력 오류", "인증번호는 6자리로 입력해주세요.");
      return;
    }
    setState(() { _isVerifyLoading = true; });
    try {
      var verifyCheckMessage = await _telAuthenticationService.verifyEmailTelVerificationCodeAndTelUpdate(_email, _tel, _verificationCodeController.text);
      if (verifyCheckMessage == "ok") {
        setState(() { _isVerifyLoading = false; });
        _customAlert.pageMovingWithshowTextAlert("인증 성공", "인증이 완료되었습니다.", "/map");
      } else {
        setState(() { _isVerifyLoading = false; });
        _customAlert.showTextAlert("인증 실패", verifyCheckMessage);
      }
    } catch (error) {
      setState(() { _isVerifyLoading = false; });
      _customAlert.showTextAlert("인증 실패", "인증번호가 올바르지 않습니다.\n다시 확인해주세요.");
    }
  }

  InputDecoration _fieldDecoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15, fontFamily: 'Pretendard'),
      filled: true,
      fillColor: _fieldBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffix: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_primaryDark, _primary, Color(0xFFA8CCFF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 인라인 앱바
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Get.back(),
                      ),
                      const Expanded(
                        child: Text(
                          '회원가입',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 카드
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '전화번호 인증',
                        style: TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 20,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '유니멀 서비스 이용을 위해\n전화번호 인증을 진행해주세요.',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

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
                              style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: Color(0xFF374151)),
                              decoration: _fieldDecoration('전화번호'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSendLoading ? null : _sendVerificationCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSendLoading ? Colors.grey[300] : _primary,
                                foregroundColor: _isSendLoading ? Colors.grey[600] : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _isSendLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                  : Text(_sendCodeText, style: const TextStyle(fontSize: 14, fontFamily: 'Pretendard', fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),

                      if (_isVerificationSent) ...[
                        const SizedBox(height: 12),
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
                                style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard', color: Color(0xFF374151)),
                                decoration: _fieldDecoration(
                                  '인증번호 6자리',
                                  suffix: _isTimerRunning
                                      ? Text(
                                          _formatTime(_remainingSeconds),
                                          style: const TextStyle(color: _primary, fontSize: 13, fontFamily: 'Pretendard', fontWeight: FontWeight.w600),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: (_isVerifyLoading || !_isTimerRunning) ? null : _verifyCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isTimerRunning ? _primary : Colors.grey[300],
                                  foregroundColor: _isTimerRunning ? Colors.white : Colors.grey[600],
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _isVerifyLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                    : const Text('인증하기', style: TextStyle(fontSize: 14, fontFamily: 'Pretendard', fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
