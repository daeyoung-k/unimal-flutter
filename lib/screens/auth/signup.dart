import 'package:flutter/material.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/screens/widget/alert/custom_alert.dart';

class SignupScreens extends StatefulWidget {
  const SignupScreens({super.key});

  @override
  State<SignupScreens> createState() => _SignupScreensState();
}

class _SignupScreensState extends State<SignupScreens> {
  final UserInfoService _userInfoService = UserInfoService();
  final CustomAlert _customAlert = CustomAlert();

  // 입력 필드 컨트롤러 선언
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // 닉네임 중복확인 상태
  bool _isNicknameVerified = false;

  String? _selectedEmailDomain;
  final List<String> _emailDomains = [
    'naver.com',
    'gmail.com',
    'daum.net',
    'kakao.com',
    'nate.com',
    '직접입력'
  ];
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
    if (RegExp(r'^[ㅏㅑㅓㅕㅗㅛㅜㅠㅡㅣㅐㅒㅔㅖㅘㅙㅚㅝㅞㅟㅢㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ]+$').hasMatch(_nicknameController.text)) {
      if (mounted) {
        _customAlert.showSnackBar(context, '정상적인 닉네임을 입력해주세요.');
      }
      return;
    }

    final String nickname = _nicknameController.text;
    final String checkNicknameMessage =
        await _userInfoService.checkNickname(nickname);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4D91FF),
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
            padding: const EdgeInsets.all(20),
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
                        onPressed: _isNicknameVerified ? null : _checkNicknameDuplicate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isNicknameVerified ? Colors.green : Colors.white,
                          foregroundColor: _isNicknameVerified ? Colors.white : const Color(0xFF4D91FF),
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
                            onPressed: null, // 비활성화
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.grey[600],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
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
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordCheckController,
                  obscureText: true,
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
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '6~20자/영문 대문자, 소문자, 숫자, 특수문자 중 2가지 이상 조합',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w300,
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
                        onPressed: null, // 비활성화
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '인증번호 받기',
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
                const SizedBox(height: 32),

                // 가입하기 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: null, // 비활성화
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
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
