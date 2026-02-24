import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  @override
  void initState() {
    super.initState();
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
              child: _userInfo?.profileImage != null
                  ? Image.network(
                      _userInfo!.profileImage!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAvatarLetter(avatarLetter),
                    )
                  : _buildAvatarLetter(avatarLetter),
            ),
          ),
          const SizedBox(width: 16),
          // 사용자 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 닉네임
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 8),
                // 소개글
                GestureDetector(
                  onTap: () {
                    // 소개글 수정 기능 (추후 구현)
                  },
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
