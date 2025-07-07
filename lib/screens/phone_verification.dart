import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/widget/alert/custom_alert.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _verificationCodeController = TextEditingController();
  final CustomAlert _customAlert = CustomAlert();
  
  bool _isVerificationSent = false;
  bool _isLoading = false;
  
  LoginType? _loginType;
  String? _email;

  @override
  void initState() {
    super.initState();
    // 전달받은 인자들 저장
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      _loginType = arguments['loginType'] as LoginType?;
      _email = arguments['email'] as String?;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  // 전화번호 형식 검증
  bool _isValidPhoneNumber(String phone) {
    return RegExp(r'^01[0-9]\d{3,4}\d{4}$').hasMatch(phone);
  }

  // 인증번호 전송
  Future<void> _sendVerificationCode() async {
    if (!_isValidPhoneNumber(_phoneController.text)) {
      _customAlert.showTextAlert("입력 오류", "올바른 전화번호 형식을 입력해주세요.\n예: 01012345678");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: 실제 인증번호 전송 API 호출
      await Future.delayed(Duration(seconds: 2)); // 임시 딜레이
      
      setState(() {
        _isVerificationSent = true;
        _isLoading = false;
      });
      
      _customAlert.showTextAlert("인증번호 전송", "인증번호가 전송되었습니다.");
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _customAlert.showTextAlert("전송 실패", "인증번호 전송에 실패했습니다.\n다시 시도해주세요.");
    }
  }

  // 인증번호 확인
  Future<void> _verifyCode() async {
    if (_verificationCodeController.text.isEmpty) {
      _customAlert.showTextAlert("입력 오류", "인증번호를 입력해주세요.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: 실제 인증번호 확인 API 호출
      await Future.delayed(Duration(seconds: 2)); // 임시 딜레이
      
      // 인증 성공 시 로그인 완료 처리
      await _completeLogin();
      
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _customAlert.showTextAlert("인증 실패", "인증번호가 올바르지 않습니다.\n다시 확인해주세요.");
    }
  }

  // 로그인 완료 처리
  Future<void> _completeLogin() async {
    try {
      // TODO: 백엔드에 인증 완료 요청
      // await _sendVerificationComplete();
      
      // 로그인 성공 시 메인 화면으로 이동
      Get.offAllNamed("/map");
    } catch (error) {
      _customAlert.showTextAlert("로그인 실패", "로그인 처리 중 오류가 발생했습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4D91FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          '전화번호 인증',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '안전한 서비스 이용을 위해\n전화번호 인증을 진행해주세요.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 40),
              
              // 전화번호 입력
              Container(
                width: double.infinity,
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    hintText: '전화번호 (예: 01012345678)',
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
              SizedBox(height: 15),
              
              // 인증번호 전송 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendVerificationCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4D91FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF4D91FF)),
                          ),
                        )
                      : Text(
                          '인증번호 전송',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              if (_isVerificationSent) ...[
                SizedBox(height: 30),
                Container(
                  width: double.infinity,
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
                    ),
                  ),
                ),
                SizedBox(height: 15),
                
                // 인증번호 확인 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4D91FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF4D91FF)),
                            ),
                          )
                        : Text(
                            '인증번호 확인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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