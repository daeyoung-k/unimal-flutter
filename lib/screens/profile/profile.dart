import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/user/model/user_info_model.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/state/auth_state.dart';

class ProfileScreens extends StatefulWidget {
  const ProfileScreens({super.key});

  @override
  State<ProfileScreens> createState() => _ProfileScreensState();
}

class _ProfileScreensState extends State<ProfileScreens> {
  final _authState = Get.find<AuthState>();
  final _accountService = AccountService();
  final _userInfoService = UserInfoService();

  UserInfoModel? _userInfo;
  bool _isLoading = true;
  bool _isUploadingImage = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// 네비게이션 탭 재탭 시 외부에서 호출되는 새로고침 메서드
  void refreshProfile() {
    _loadUserInfo();
  }

  /// GET /user/member/info 호출 후 결과를 _userInfo에 저장
  Future<void> _loadUserInfo() async {
    final info = await _userInfoService.getMemberInfo(_authState.accessToken.value);
    if (mounted) {
      setState(() {
        _userInfo = info;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4D91FF),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  // 프로필 헤더
                  _buildProfileHeader(),
                  const SizedBox(height: 20),
                  // 내 소식 탭 헤더
                  _buildTabBar(),
                  const SizedBox(height: 20),
                  // 내 소식 콘텐츠
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
      ),
    );
  }

  // 프로필 헤더 위젯
  Widget _buildProfileHeader() {
    // 닉네임 우선, 없으면 이름, 없으면 기본값
    final displayName = _userInfo?.nickname.isNotEmpty == true
        ? _userInfo!.nickname
        : (_userInfo?.name.isNotEmpty == true ? _userInfo!.name : '사용자');
    final avatarLetter = displayName.isNotEmpty ? displayName[0] : 'U';
    final introduction = _userInfo?.introduction.isNotEmpty == true
        ? _userInfo!.introduction
        : '탭하고 소개 글을 입력해 보세요';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 프로필 아바타
          GestureDetector(
            onTap: _isUploadingImage ? null : _pickAndUploadProfileImage,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _isUploadingImage
                        ? Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4D91FF),
                              ),
                            ),
                          )
                        : (_userInfo?.profileImage != null
                            ? Image.network(
                                _userInfo!.profileImage!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildAvatarLetter(avatarLetter),
                              )
                            : _buildAvatarLetter(avatarLetter)),
                  ),
                ),
                // 카메라 아이콘 뱃지
                if (!_isUploadingImage)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF4D91FF), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 13,
                        color: Color(0xFF4D91FF),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 사용자 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 닉네임
                GestureDetector(
                  onTap: _showEditNicknameSheet,
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 소개글
                GestureDetector(
                  onTap: _showEditIntroductionSheet,
                  child: Text(
                    introduction,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 설정 아이콘
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 24,
            ),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
    );
  }

  // 이니셜 아바타 위젯 (프로필 이미지 없을 때 폴백)
  Widget _buildAvatarLetter(String letter) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4D91FF),
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }

  // 내 소식 탭 헤더
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white, width: 2),
          ),
        ),
        child: const Text(
          '내 소식',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }

  // 내 소식 콘텐츠 위젯
  Widget _buildContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '발길 닿은 곳의 이야기를 기록해보세요',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontFamily: 'Pretendard',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // 첫 발자국 남기기 기능 (추후 구현)
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 14,
              ),
            ),
            child: const Text(
              '첫 발자국 남기기',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 프로필 이미지 선택 및 업로드
  Future<void> _pickAndUploadProfileImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    if (!mounted) return;
    setState(() => _isUploadingImage = true);

    final success = await _userInfoService.uploadProfileImage(
      accessToken: _authState.accessToken.value,
      imageFile: File(picked.path),
    );

    if (success && mounted) {
      await _loadUserInfo();
    }

    if (mounted) {
      setState(() => _isUploadingImage = false);
    }
  }

  /// 닉네임 수정 바텀시트 표시
  void _showEditNicknameSheet() {
    final controller = TextEditingController(text: _userInfo?.nickname ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isSaving = false;
        String? errorText;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '닉네임 수정',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 20,
                    onChanged: (_) {
                      if (errorText != null) {
                        setSheetState(() => errorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '닉네임을 입력해 주세요',
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final nickname = controller.text.trim();
                              if (nickname.isEmpty) return;

                              setSheetState(() {
                                isSaving = true;
                                errorText = null;
                              });

                              // 현재 닉네임과 동일하면 중복검사 생략
                              if (nickname != _userInfo?.nickname) {
                                final result = await _userInfoService.checkNickname(nickname);
                                if (result != 'ok') {
                                  setSheetState(() {
                                    isSaving = false;
                                    errorText = result;
                                  });
                                  return;
                                }
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                              await _updateNickname(nickname);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4D91FF),
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '저장',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateNickname(String nickname) async {
    final success = await _userInfoService.updateMemberInfo(
      accessToken: _authState.accessToken.value,
      nickname: nickname,
      introduction: _userInfo?.introduction ?? '',
    );
    if (success && mounted) {
      await _loadUserInfo();
    }
  }

  /// 소개글 수정 바텀시트 표시
  void _showEditIntroductionSheet() {
    final controller = TextEditingController(text: _userInfo?.introduction ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '소개글 수정',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Pretendard',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                autofocus: true,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: '나를 소개해 보세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _updateIntroduction(controller.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4D91FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '저장',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateIntroduction(String introduction) async {
    final success = await _userInfoService.updateMemberInfo(
      accessToken: _authState.accessToken.value,
      nickname: _userInfo?.nickname ?? '',
      introduction: introduction,
    );
    if (success && mounted) {
      await _loadUserInfo();
    }
  }

  /// 설정 바텀시트 표시 (내 개인정보 / 설정 / 로그아웃)
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // 드래그 핸들
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text(
                  '내 개인정보',
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                  ),
                ),
                onTap: () {
                  Get.back();
                  // 내 개인정보 화면 (추후 구현)
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text(
                  '설정',
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                  ),
                ),
                onTap: () {
                  Get.back();
                  // 설정 화면 (추후 구현)
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  '로그아웃',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.red,
                    fontFamily: 'Pretendard',
                  ),
                ),
                onTap: () {
                  Get.back();
                  _showLogoutDialog();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 로그아웃 다이얼로그 표시
  void _showLogoutDialog() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '로그아웃',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Pretendard',
          ),
        ),
        content: const Text(
          '정말 로그아웃 하시겠습니까?',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Pretendard',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              '취소',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await _accountService.logout();
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
