import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/navigation/app_routes.dart';
import 'package:unimal/state/nav_controller.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key, this.selectedIndex = 0});

  final int selectedIndex;

  @override
  State<StatefulWidget> createState() => _RootScreen();
}

class _RootScreen extends State<RootScreen> {
  final appRoutes = AppRoutes();
  late final NavController _nav;

  @override
  void initState() {
    super.initState();
    _nav = Get.put(NavController());
    _nav.selectedIndex.value = widget.selectedIndex;
  }

  void _onItemTapped(int index) {
    final current = _nav.selectedIndex.value;
    // 지도 탭(인덱스 0)을 이미 선택한 상태에서 다시 터치하면 새로고침
    if (index == 0 && current == 0) {
      final mapState = appRoutes.mapScreenKey.currentState;
      if (mapState != null) {
        try { (mapState as dynamic).refreshMap(); } catch (_) {}
      }
    }
    // 게시판 탭(인덱스 2)을 이미 선택한 상태에서 다시 터치하면 새로고침
    else if (index == 2 && current == 2) {
      final boardState = appRoutes.boardScreenKey.currentState;
      if (boardState != null) {
        try { (boardState as dynamic).refreshPosts(); } catch (_) {}
      }
    }
    // My 탭(인덱스 3)을 이미 선택한 상태에서 다시 터치하면 새로고침
    else if (index == 3 && current == 3) {
      final profileState = appRoutes.profileScreenKey.currentState;
      if (profileState != null) {
        try { (profileState as dynamic).refreshProfile(); } catch (_) {}
      }
    } else {
      _nav.selectedIndex.value = index;
    }
  }

  static const Color _active = Color(0xFF5B9FEF);
  static const Color _inactive = Color(0xFF9E9E9E);

  static const _navItems = [
    {'icon': 'assets/icon/svg/map_icon.svg', 'activeIcon': 'assets/icon/svg/map_bold_icon.svg', 'label': '지도'},
    {'icon': 'assets/icon/svg/additem_icon.svg', 'activeIcon': 'assets/icon/svg/additem_bold_icon.svg', 'label': '공유하기'},
    {'icon': 'assets/icon/svg/clipboard_icon.svg', 'activeIcon': 'assets/icon/svg/clipboard_bold_icon.svg', 'label': '게시판'},
    {'icon': 'assets/icon/svg/user_icon.svg', 'activeIcon': 'assets/icon/svg/user_bold_icon.svg', 'label': 'My'},
  ];

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8E8E8), width: 1)),
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isActive = _nav.selectedIndex.value == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onItemTapped(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        isActive ? item['activeIcon']! : item['icon']!,
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          isActive ? _active : _inactive,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['label']!,
                        style: TextStyle(
                          color: isActive ? _active : _inactive,
                          fontSize: 11,
                          fontFamily: 'Pretendard',
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
      body: IndexedStack(
        index: _nav.selectedIndex.value,
        children: appRoutes.bottomNavigationPages(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    ));
  }
}
