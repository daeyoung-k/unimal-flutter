import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unimal/screens/profile/mypage/mypage.dart';
import 'package:unimal/screens/profile/setting/setting.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/user/model/user_info_model.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/state/nav_controller.dart';

class ProfileScreens extends StatefulWidget {
  const ProfileScreens({super.key});

  @override
  State<ProfileScreens> createState() => _ProfileScreensState();
}

class _ProfileScreensState extends State<ProfileScreens>
    with SingleTickerProviderStateMixin {
  final _authState = Get.find<AuthState>();
  final _accountService = AccountService();
  final _userInfoService = UserInfoService();
  final _boardApiService = BoardApiService();

  UserInfoModel? _userInfo;
  int _myPostCount = 0;
  int _myLikeCount = 0;
  bool _isLoading = true;
  bool _isUploadingImage = false;
  final _picker = ImagePicker();

  bool _lastTickerEnabled = false;
  late AnimationController _ctrl;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;
  late Animation<Offset> _statsSlide;
  late Animation<double> _statsFade;
  late Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headerSlide = Tween(begin: const Offset(0, -0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _headerFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.45, curve: Curves.easeOut)),
    );
    _statsSlide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.65, curve: Curves.easeOut)),
    );
    _statsFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.6, curve: Curves.easeOut)),
    );
    _contentFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );
    _loadUserInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.of(context);
    if (tickerEnabled && !_lastTickerEnabled && !_isLoading) {
      _ctrl.forward(from: 0);
    }
    _lastTickerEnabled = tickerEnabled;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 네비게이션 탭 재탭 시 외부에서 호출되는 새로고침 메서드
  void refreshProfile() {
    _loadUserInfo();
  }

  /// GET /user/member/info, /board/post/total, /board/post/total/like 병렬 호출
  Future<void> _loadUserInfo() async {
    final results = await Future.wait([
      _userInfoService.getMemberInfo(_authState.accessToken.value),
      _boardApiService.getMyPostTotal(),
      _boardApiService.getMyLikeTotal(),
    ]);
    if (mounted) {
      setState(() {
        _userInfo = results[0] as UserInfoModel?;
        _myPostCount = (results[1] as int?) ?? 0;
        _myLikeCount = (results[2] as int?) ?? 0;
        _isLoading = false;
      });
      _ctrl.forward(from: 0);
    }
  }

  static const Color _primary = Color(0xFF7AB3FF);
  static const Color _primaryDark = Color(0xFF3578E5);
  static const Color _accent = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_primaryDark, _primary, Color(0xFFA8CCFF)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    FadeTransition(
                      opacity: _headerFade,
                      child: SlideTransition(
                        position: _headerSlide,
                        child: _buildProfileHeader(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _statsFade,
                      child: SlideTransition(
                        position: _statsSlide,
                        child: _buildStatsCard(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _contentFade,
                      child: Column(
                        children: [
                          _buildTabBar(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FadeTransition(
                        opacity: _contentFade,
                        child: _buildContent(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                icon: Icons.location_on_rounded,
                iconColor: _primary,
                value: _myPostCount.toString(),
                label: '내 스토리',
              ),
            ),
            Container(width: 1, height: 48, color: const Color(0xFFE8E8E8)),
            Expanded(
              child: _buildStatItem(
                icon: Icons.favorite_rounded,
                iconColor: _accent,
                value: _myLikeCount.toString(),
                label: '받은 좋아요',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            fontFamily: 'Pretendard',
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontFamily: 'Pretendard',
          ),
        ),
      ],
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
                                color: _primary,
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
                        border: Border.all(color: _primary, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 13,
                        color: _primary,
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
            color: _primary,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }

  // 내 스토리 탭 헤더
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
          '내 스토리',
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

  // 내 스토리 콘텐츠 위젯
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
              Get.find<NavController>().selectedIndex.value = 1;
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
              '첫 스토리 남기기',
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
                        backgroundColor: _primary,
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
                    backgroundColor: _primary,
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
                onTap: () async {
                  Get.back();
                  await Get.to(() => const MyPageScreen());
                  _loadUserInfo();
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
                  Get.to(() => const SettingScreen());
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
