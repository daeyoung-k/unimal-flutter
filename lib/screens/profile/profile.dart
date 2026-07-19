import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unimal/screens/profile/mypage/mypage.dart';
import 'package:unimal/screens/profile/mypage/my_story_map_card.dart';
import 'package:unimal/screens/profile/mypage/story_list.dart';
import 'package:unimal/screens/profile/setting/setting.dart';
// AdMob 인증 완료 후 광고 노출 시 주석 해제.
// import 'package:unimal/service/ads/ad_banner.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/user/model/user_info_model.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/state/nav_controller.dart';
import 'package:unimal/theme/app_colors.dart';

class ProfileScreens extends StatefulWidget {
  const ProfileScreens({super.key});

  @override
  State<ProfileScreens> createState() => _ProfileScreensState();
}

class _ProfileScreensState extends State<ProfileScreens> {
  final _authState = Get.find<AuthState>();
  final _accountService = AccountService();
  final _userInfoService = UserInfoService();
  final _boardApiService = BoardApiService();
  final _picker = ImagePicker();

  UserInfoModel? _userInfo;
  int _myPostCount = 0;
  int _myLikedCount = 0;
  List<BoardPost> _myPosts = [];
  bool _isLoading = true;
  bool _isUploadingImage = false;

  // 메뉴 영역 임시 숨김 (true로 바꾸면 부활).
  // - '좋아요한 스토리'는 내 지도 화면에서 보는 버튼으로 이전 예정
  // - 팔로우 등 기능이 추가되면 이 영역을 다시 노출
  // 코드/데이터(_myLikedCount, _buildMenuCard 등)는 그대로 유지한다.
  static bool _showMenuSection = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void refreshProfile() => _loadUserInfo();

  Future<void> _loadUserInfo() async {
    // Future.wait 는 하나라도 던지면 통째로 reject 되고, 그대로 두면
    // _isLoading 이 영원히 true 로 남아 무한 스피너가 된다 (네트워크 예외,
    // 토큰 재발급 실패 등). 실패해도 화면은 빈 상태로라도 뜨게 방어한다.
    List<Object?>? results;
    try {
      results = await Future.wait([
        _userInfoService.getMemberInfo(_authState.accessToken.value),
        _boardApiService.getMyPostTotal(),
        _boardApiService.getMyLikedTotal(),
        _boardApiService.getMyPostList(sortType: 'LATEST'),
      ]);
    } catch (e, st) {
      debugPrint('[profile] 내 정보 로드 실패: $e\n$st');
    }
    if (mounted) {
      setState(() {
        if (results != null) {
          _userInfo = results[0] as UserInfoModel?;
          _myPostCount = (results[1] as int?) ?? 0;
          _myLikedCount = (results[2] as int?) ?? 0;
          _myPosts = (results[3] as List<BoardPost>?) ?? [];
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: colors.primaryStrong, strokeWidth: 2))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(colors),
                    const SizedBox(height: 16),
                    _buildStorySection(colors),
                    if (_showMenuSection) ...[
                      const SizedBox(height: 14),
                      _buildSectionLabel('메뉴', colors),
                      const SizedBox(height: 8),
                      _buildMenuCard(colors),
                    ],
                    const SizedBox(height: 14),
                    _buildSectionLabel('더보기', colors),
                    const SizedBox(height: 8),
                    _buildMoreCard(colors),
                  ],
                ),
                    ),
                  ),
                  // AdMob 인증 완료 전까지 광고 미노출. 인증 완료 후 주석 해제.
                  // const AdBanner(),
                ],
              ),
            ),
    );
  }

  // ── 히어로 카드 ──────────────────────────────────────────────────────
  Widget _buildHeroCard(AppColors colors) {
    final displayName = _userInfo?.nickname.isNotEmpty == true
        ? _userInfo!.nickname
        : (_userInfo?.name.isNotEmpty == true ? _userInfo!.name : '사용자');
    final introduction = _userInfo?.introduction.isNotEmpty == true
        ? _userInfo!.introduction
        : '탭하고 소개 글을 입력해 보세요';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primarySoft],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // 아바타 + 카메라 뱃지
          GestureDetector(
            onTap: _isUploadingImage ? null : _pickAndUploadProfileImage,
            child: Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9), width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isUploadingImage
                      ? Container(
                          color: Colors.white.withValues(alpha: 0.5),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: colors.primary),
                        )
                      : (_userInfo?.profileImage != null &&
                              _userInfo!.profileImage!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _userInfo!.profileImage!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _buildAvatarLetter(displayName, colors),
                            )
                          : _buildAvatarLetter(displayName, colors)),
                ),
                if (!_isUploadingImage)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: colors.primary.withValues(alpha: 0.4),
                            width: 1),
                      ),
                      child: Icon(Icons.add_a_photo_outlined,
                          size: 11, color: colors.primary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // 닉네임 + 소개글
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _showEditNicknameSheet,
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _showEditIntroductionSheet,
                  child: Text(
                    introduction,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontFamily: 'Pretendard',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 스토리 카운트
          Column(
            children: [
              Text(
                _myPostCount.toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'Pretendard',
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '스토리',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontFamily: 'Pretendard',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarLetter(String displayName, AppColors colors) {
    final letter = displayName.isNotEmpty ? displayName[0] : 'U';
    return Container(
      color: colors.primaryWash,
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colors.primary,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }

  // ── 내 스토리 → 지도 미리보기 ──────────────────────────────────────────
  Widget _buildStorySection(AppColors colors) {
    // 스토리가 없으면 헤더 없이 빈 상태 카드만 노출.
    if (_myPosts.isEmpty) return _buildEmptyStripCard(colors);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '내 지도 보기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Pretendard',
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        MyStoryMapCard(
          posts: _myPosts,
          storyCount: _myPostCount,
          onTap: () => Get.toNamed('/my-story-map'),
        ),
      ],
    );
  }

  // ── 빈 상태 카드 (figma empty-card 119:43) ───────────────────────────
  Widget _buildEmptyStripCard(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(
            '아직 스토리가 없어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontFamily: 'Pretendard',
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '발길 닿은 곳의 이야기를 기록해보세요',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Pretendard',
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Get.find<NavController>().requestShareSheet(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [colors.primary, colors.primarySoft],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '첫 스토리 남기기',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontFamily: 'Pretendard',
          color: colors.textSecondary,
        ),
      ),
    );
  }

  // ── 메뉴 카드 ─────────────────────────────────────────────────────────
  Widget _buildMenuCard(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _buildMenuRow(
            colors: colors,
            icon: Icons.favorite_border_rounded,
            label: '좋아요한 스토리',
            count: _myLikedCount,
            iconColor: colors.accentCoral,
            onTap: () => Get.toNamed('/story-list',
                arguments: {'mode': StoryListMode.likedStories}),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuRow({
    required AppColors colors,
    required IconData icon,
    required String label,
    required int count,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? colors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor ?? colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  // ── 더보기 카드 ───────────────────────────────────────────────────────
  Widget _buildMoreCard(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _buildMoreRow(
            colors: colors,
            icon: Icons.notifications_active_outlined,
            label: '공지사항',
            onTap: () => Get.toNamed('/notice-list'),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: colors.divider),
          _buildMoreRow(
            colors: colors,
            icon: Icons.settings_outlined,
            label: '설정',
            onTap: _showSettingsSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildMoreRow({
    required AppColors colors,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: colors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  // ── 프로필 이미지 업로드 ─────────────────────────────────────────────
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
    if (success && mounted) await _loadUserInfo();
    if (mounted) setState(() => _isUploadingImage = false);
  }

  // ── 닉네임 수정 ──────────────────────────────────────────────────────
  void _showEditNicknameSheet() {
    final controller =
        TextEditingController(text: _userInfo?.nickname ?? '');
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool isSaving = false;
        String? errorText;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('닉네임 수정',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Pretendard')),
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
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                            setSheetState(() => isSaving = true);
                            if (nickname != _userInfo?.nickname) {
                              final result = await _userInfoService
                                  .checkNickname(nickname);
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
                      backgroundColor: colors.primary,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('저장',
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _updateNickname(String nickname) async {
    final success = await _userInfoService.updateMemberInfo(
      accessToken: _authState.accessToken.value,
      nickname: nickname,
      introduction: _userInfo?.introduction ?? '',
    );
    if (success && mounted) await _loadUserInfo();
  }

  // ── 소개글 수정 ──────────────────────────────────────────────────────
  void _showEditIntroductionSheet() {
    final controller =
        TextEditingController(text: _userInfo?.introduction ?? '');
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('소개글 수정',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Pretendard')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: '나를 소개해 보세요',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
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
                  backgroundColor: colors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('저장',
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateIntroduction(String introduction) async {
    final success = await _userInfoService.updateMemberInfo(
      accessToken: _authState.accessToken.value,
      nickname: _userInfo?.nickname ?? '',
      introduction: introduction,
    );
    if (success && mounted) await _loadUserInfo();
  }

  // ── 설정 시트 ─────────────────────────────────────────────────────────
  void _showSettingsSheet() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  Icon(Icons.person_outline, color: colors.textSecondary),
              title: const Text('내 개인정보',
                  style:
                      TextStyle(fontSize: 15, fontFamily: 'Pretendard')),
              onTap: () async {
                Get.back();
                await Get.to(() => const MyPageScreen());
                _loadUserInfo();
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.tune_outlined, color: colors.textSecondary),
              title: const Text('설정',
                  style:
                      TextStyle(fontSize: 15, fontFamily: 'Pretendard')),
              onTap: () {
                Get.back();
                Get.to(() => const SettingScreen());
              },
            ),
            Divider(height: 1, color: colors.divider),
            ListTile(
              leading: Icon(Icons.logout, color: colors.danger),
              title: Text('로그아웃',
                  style: TextStyle(
                      fontSize: 15,
                      color: colors.danger,
                      fontFamily: 'Pretendard')),
              onTap: () {
                Get.back();
                _showLogoutDialog(colors);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(AppColors colors) {
    Get.dialog(AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('로그아웃',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Pretendard')),
      content: const Text('정말 로그아웃 하시겠습니까?',
          style: TextStyle(fontSize: 16, fontFamily: 'Pretendard')),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('취소',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontFamily: 'Pretendard')),
        ),
        TextButton(
          onPressed: () async {
            Get.back();
            await _accountService.logout();
          },
          child: Text('로그아웃',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.danger,
                  fontFamily: 'Pretendard')),
        ),
      ],
    ));
  }
}
