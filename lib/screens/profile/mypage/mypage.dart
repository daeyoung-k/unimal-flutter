import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/user/model/user_info_model.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/state/auth_state.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  static const Color _primary = Color(0xFF5B9FEF);
  static const Color _primaryDark = Color(0xFF3578E5);

  final _authState = Get.find<AuthState>();
  final _userInfoService = UserInfoService();
  final _accountService = AccountService();

  UserInfoModel? _userInfo;
  bool _isLoading = true;
  bool _isSaving = false;

  // 편집용 컨트롤러
  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  String _birthday = '';
  String _gender = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nicknameController = TextEditingController();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final info = await _userInfoService.getMemberInfo(_authState.accessToken.value);
    if (mounted) {
      setState(() {
        _userInfo = info;
        _nameController.text = info?.name ?? '';
        _nicknameController.text = info?.nickname ?? '';
        _birthday = info?.birthday ?? '';
        _gender = info?.gender ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    final name = _nameController.text.trim();

    if (nickname.isEmpty) {
      Get.snackbar('오류', '닉네임을 입력해주세요',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[50],
          colorText: Colors.red);
      return;
    }

    // 닉네임이 변경된 경우 중복 확인
    if (nickname != _userInfo?.nickname) {
      setState(() => _isSaving = true);
      final check = await _userInfoService.checkNickname(nickname);
      if (check != 'ok') {
        setState(() => _isSaving = false);
        Get.snackbar('닉네임 오류', check,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red[50],
            colorText: Colors.red);
        return;
      }
    }

    setState(() => _isSaving = true);
    final success = await _userInfoService.updatePersonalInfo(
      accessToken: _authState.accessToken.value,
      name: name,
      nickname: nickname,
      tel: _userInfo?.tel ?? '',
      introduction: _userInfo?.introduction ?? '',
      birthday: _birthday,
      gender: _gender,
    );
    setState(() => _isSaving = false);

    if (success) {
      await _loadUserInfo();
      Get.snackbar('완료', '개인정보가 저장되었습니다',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[50],
          colorText: Colors.green[800]);
    } else {
      Get.snackbar('오류', '저장에 실패했습니다. 다시 시도해주세요',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[50],
          colorText: Colors.red);
    }
  }

  Future<void> _pickBirthday() async {
    DateTime initial = DateTime(2000);
    if (_birthday.isNotEmpty) {
      try {
        final parts = _birthday.split('-');
        if (parts.length == 3) {
          initial = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (_) {}
    }

    DateTime tempPicked = initial;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              // 핸들 + 확인 버튼
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('취소',
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey,
                              fontFamily: 'Pretendard')),
                    ),
                    const Text('생년월일',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Pretendard')),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _birthday =
                              '${tempPicked.year}-${tempPicked.month.toString().padLeft(2, '0')}-${tempPicked.day.toString().padLeft(2, '0')}';
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('확인',
                          style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF4D91FF),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Pretendard')),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 스크롤 휠
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (dt) => tempPicked = dt,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGenderSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '성별 선택',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      title: const Text('남성',
                          style: TextStyle(fontSize: 15, fontFamily: 'Pretendard')),
                      value: 'MALE',
                      groupValue: _gender,
                      activeColor: _primary,
                      onChanged: (val) {
                        setSheetState(() {});
                        setState(() => _gender = val!);
                        Navigator.pop(ctx);
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('여성',
                          style: TextStyle(fontSize: 15, fontFamily: 'Pretendard')),
                      value: 'FEMALE',
                      groupValue: _gender,
                      activeColor: _primary,
                      onChanged: (val) {
                        setSheetState(() {});
                        setState(() => _gender = val!);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTelChangeSheet() {
    final telController = TextEditingController();
    final codeController = TextEditingController();
    bool codeSent = false;
    bool isSendingCode = false;
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 핸들
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '휴대폰 번호 변경',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 번호 입력 + 인증번호 발송
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: telController,
                          keyboardType: TextInputType.phone,
                          enabled: !codeSent,
                          style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard'),
                          decoration: InputDecoration(
                            hintText: '새 휴대폰 번호 입력',
                            hintStyle: const TextStyle(
                                fontSize: 15, color: Colors.black38, fontFamily: 'Pretendard'),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            filled: codeSent,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: (isSendingCode || codeSent)
                            ? null
                            : () async {
                                final tel = telController.text.trim();
                                if (tel.isEmpty) {
                                  Get.snackbar('오류', '번호를 입력해주세요',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.red[50],
                                      colorText: Colors.red);
                                  return;
                                }
                                if (tel == _userInfo?.tel) {
                                  Get.snackbar('오류', '현재 사용중인 번호와 동일한 번호로 변경할 수 없습니다',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.red[50],
                                      colorText: Colors.red);
                                  return;
                                }
                                setSheetState(() => isSendingCode = true);
                                final result = await _userInfoService
                                    .sendTelVerificationCode(_authState.accessToken.value, _authState.email.value, tel);
                                setSheetState(() => isSendingCode = false);
                                if (result == 'ok') {
                                  setSheetState(() => codeSent = true);
                                  Get.snackbar('완료', '인증번호가 발송되었습니다',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.green[50],
                                      colorText: Colors.green[800]);
                                } else {
                                  Get.snackbar('오류', result,
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.red[50],
                                      colorText: Colors.red);
                                }
                              },
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: (isSendingCode || codeSent)
                                ? Colors.grey[200]
                                : const Color(0xFF4D91FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: isSendingCode
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    codeSent ? '발송됨' : '인증번호 발송',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: codeSent ? Colors.black38 : Colors.white,
                                      fontFamily: 'Pretendard',
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 인증번호 입력 (발송 후 표시)
                  if (codeSent) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeController,
                            keyboardType: TextInputType.number,
                            style:
                                const TextStyle(fontSize: 15, fontFamily: 'Pretendard'),
                            decoration: InputDecoration(
                              hintText: '인증번호 입력',
                              hintStyle: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black38,
                                  fontFamily: 'Pretendard'),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: isVerifying
                              ? null
                              : () async {
                                  final code = codeController.text.trim();
                                  final tel = telController.text.trim();
                                  if (code.isEmpty) {
                                    Get.snackbar('오류', '인증번호를 입력해주세요',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.red[50],
                                        colorText: Colors.red);
                                    return;
                                  }
                                  setSheetState(() => isVerifying = true);
                                  final result = await _userInfoService.verifyAndUpdateTel(
                                      _authState.accessToken.value, code, _authState.email.value, tel);
                                  setSheetState(() => isVerifying = false);
                                  if (result != null && !result.containsKey('error')) {
                                    // 토큰 업데이트
                                    await _authState.setTokens(
                                      result['accessToken']!,
                                      result['refreshToken']!,
                                      result['email']!,
                                      _authState.provider.value,
                                    );
                                    Navigator.pop(ctx);
                                    await _loadUserInfo();
                                    Get.snackbar('완료', '휴대폰 번호가 변경되었습니다',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.green[50],
                                        colorText: Colors.green[800]);
                                  } else {
                                    final msg = result?['error'] ?? '인증에 실패했습니다. 인증번호를 확인해주세요';
                                    Get.snackbar('오류', msg,
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.red[50],
                                        colorText: Colors.red);
                                  }
                                },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: isVerifying
                                  ? Colors.grey[200]
                                  : const Color(0xFF3578E5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: isVerifying
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text(
                                      '확인',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        fontFamily: 'Pretendard',
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '내 개인정보',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontFamily: 'Pretendard',
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4D91FF)))
          : Column(
              children: [
                Expanded(child: _buildContent()),
                _buildBottomButtons(),
              ],
            ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // 이름 (텍스트 편집)
        _buildEditableTextField(
          label: '이름',
          controller: _nameController,
          hint: '이름을 입력하세요',
        ),
        _buildDivider(),
        // 닉네임 (텍스트 편집)
        _buildEditableTextField(
          label: '닉네임',
          controller: _nicknameController,
          hint: '닉네임을 입력하세요',
        ),
        _buildDivider(),
        // 이메일 (수정 불가)
        _buildReadOnlyItem(label: '이메일', value: _userInfo?.email ?? '-', disabled: true),
        _buildDivider(),
        // 휴대폰 번호 (변경 가능)
        _buildTappableItem(
          label: '휴대폰 번호',
          value: _userInfo?.tel.isNotEmpty == true ? _userInfo!.tel : '번호를 등록하세요',
          valueColor: _userInfo?.tel.isNotEmpty == true ? Colors.black87 : Colors.black38,
          onTap: _showTelChangeSheet,
        ),
        _buildDivider(),
        // 생년월일 (날짜 선택)
        _buildTappableItem(
          label: '생년월일',
          value: _birthday.isNotEmpty ? _birthday : '날짜를 선택하세요',
          valueColor: _birthday.isNotEmpty ? Colors.black87 : Colors.black38,
          onTap: _pickBirthday,
        ),
        _buildDivider(),
        // 성별 (라디오 선택)
        _buildTappableItem(
          label: '성별',
          value: _genderLabel(_gender),
          valueColor: _gender.isNotEmpty ? Colors.black87 : Colors.black38,
          onTap: _showGenderSheet,
        ),
      ],
    );
  }

  Widget _buildEditableTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontFamily: 'Pretendard',
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 15,
                  color: Colors.black38,
                  fontFamily: 'Pretendard',
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyItem({required String label, required String value, bool disabled = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 15, color: Colors.black54, fontFamily: 'Pretendard')),
          Row(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: disabled ? Colors.black38 : Colors.black87,
                      fontFamily: 'Pretendard')),
              if (disabled) ...[
                const SizedBox(width: 6),
                const Icon(Icons.lock_outline, size: 14, color: Colors.black26),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTappableItem({
    required String label,
    required String value,
    required VoidCallback onTap,
    Color valueColor = Colors.black87,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 15, color: Colors.black54, fontFamily: 'Pretendard')),
            Row(
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: valueColor,
                        fontFamily: 'Pretendard')),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey[200]);
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _isSaving ? null : _save,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: _isSaving
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_primaryDark, _primary],
                        ),
                  color: _isSaving ? Color(0xFFE0E0E0) : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isSaving
                      ? []
                      : [
                          BoxShadow(
                            color: _primaryDark.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          '저장하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 60),
            Divider(height: 1, color: Colors.grey[200]),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _showWithdrawalDialog,
              child: const Text(
                '탈퇴하기',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black26,
                  fontFamily: 'Pretendard',
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.black26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawalDialog() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '회원 탈퇴',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
        ),
        content: const Text(
          '탈퇴하면 모든 데이터가 삭제되며\n복구할 수 없습니다.\n정말 탈퇴하시겠습니까?',
          style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
              fontFamily: 'Pretendard',
              height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('취소',
                style: TextStyle(
                    fontSize: 15, color: Colors.grey, fontFamily: 'Pretendard')),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await _accountService.withdrawal();
            },
            child: const Text('탈퇴',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                    fontFamily: 'Pretendard')),
          ),
        ],
      ),
    );
  }

  String _genderLabel(String? gender) {
    switch (gender) {
      case 'MALE':
        return '남성';
      case 'FEMALE':
        return '여성';
      default:
        return '선택하세요';
    }
  }
}
