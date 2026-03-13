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
                      activeColor: const Color(0xFF4D91FF),
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
                      activeColor: const Color(0xFF4D91FF),
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
        _buildReadOnlyItem(label: '이메일', value: _userInfo?.email ?? '-'),
        _buildDivider(),
        // 휴대폰 번호 (수정 불가)
        _buildReadOnlyItem(label: '휴대폰 번호', value: _userInfo?.tel.isNotEmpty == true ? _userInfo!.tel : '-'),
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

  Widget _buildReadOnlyItem({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 15, color: Colors.black54, fontFamily: 'Pretendard')),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  fontFamily: 'Pretendard')),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4D91FF),
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
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
