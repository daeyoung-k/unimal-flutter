import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/state/auth_state.dart';

class ProfileScreens extends StatefulWidget {
  const ProfileScreens({super.key});

  @override
  State<ProfileScreens> createState() => _ProfileScreensState();
}

class _ProfileScreensState extends State<ProfileScreens> {
  int _selectedTab = 0; // 0: 데이로그, 1: 큐레이션
  final _authState = Get.find<AuthState>();
  final _accountService = AccountService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4D91FF),
      body: SafeArea(
        child: Column(
          children: [
            // 프로필 헤더
            _buildProfileHeader(),
            const SizedBox(height: 20),
            // 탭 바
            _buildTabBar(),
            const SizedBox(height: 20),
            // 메인 콘텐츠
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 사진
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _authState.provider.value.name.isNotEmpty
                      ? Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Text(
                              _authState.provider.value.name.isNotEmpty
                                  ? _authState.provider.value.name[0]
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4D91FF),
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 40,
                          color: const Color(0xFF4D91FF),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // 사용자 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 사용자명
                    Text(
                      _authState.provider.value.name.isNotEmpty
                          ? _authState.provider.value.name
                          : '사용자',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 팔로워/팔로잉
                    Row(
                      children: [
                        const Text(
                          '팔로워 0',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '팔로잉 1',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 바이오 입력 프롬프트
                    GestureDetector(
                      onTap: () {
                        // 바이오 입력 기능 (추후 구현)
                      },
                      child: Text(
                        '탭하고 소개 글을 입력해 보세요',
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
              // 오른쪽 상단 아이콘들
              Column(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.ios_share_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      // 공유 기능 (추후 구현)
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      _showLogoutDialog();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 인사이트 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // 인사이트 화면 (추후 구현)
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.black, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: Colors.black,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '인사이트',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 탭 바 위젯
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
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  '데이로그',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.w400,
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = 1;
                });
              },
              child: Container(
                padding: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  '큐레이션',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.w400,
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 메인 콘텐츠 위젯
  Widget _buildContent() {
    if (_selectedTab == 0) {
      // 데이로그 탭
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '내가 방문한 공간을 기록해보세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontFamily: 'Pretendard',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // 첫 데이로그 남기기 기능 (추후 구현)
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
                '첫 데이로그 남기기',
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
    } else {
      // 큐레이션 탭
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '큐레이션을 시작해보세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontFamily: 'Pretendard',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // 큐레이션 생성 기능 (추후 구현)
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
                '첫 큐레이션 만들기',
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
            onPressed: () {
              Get.back(); // 다이얼로그 닫기
            },
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
              Get.back(); // 다이얼로그 닫기
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
