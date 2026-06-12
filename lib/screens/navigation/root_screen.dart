import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/add/share_card_sheet.dart';
import 'package:unimal/screens/navigation/app_routes.dart';
import 'package:unimal/state/nav_controller.dart';
import 'package:unimal/theme/app_colors.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({
    super.key,
    this.selectedIndex = 0,
    this.openShareSheet = false,
  });

  final int selectedIndex;

  /// true 면 진입 직후 공유하기 시트를 연다 (`/add` 딥링크용).
  final bool openShareSheet;

  @override
  State<StatefulWidget> createState() => _RootScreen();
}

class _RootScreen extends State<RootScreen> {
  final appRoutes = AppRoutes();
  late final NavController _nav;
  late final Worker _shareSheetWorker;
  bool _isShareSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _nav = Get.put(NavController());
    // 공유하기(인덱스 1)는 탭이 아니라 액션 버튼 — 탭 인덱스로 저장하지 않는다.
    _nav.selectedIndex.value =
        widget.selectedIndex == 1 ? 0 : widget.selectedIndex;
    _shareSheetWorker =
        ever<int>(_nav.shareSheetRequest, (_) => _openShareSheet());
    if (widget.openShareSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openShareSheet());
    }
  }

  @override
  void dispose() {
    _shareSheetWorker.dispose();
    super.dispose();
  }

  /// 네비 아이템은 3개(지도/공유하기/My)지만 스택 페이지는 2개(지도/My).
  /// 탭 0 → 스택 0, 탭 2 → 스택 1.
  int _stackIndexFor(int tabIndex) => tabIndex == 2 ? 1 : 0;

  Future<void> _openShareSheet() async {
    if (!mounted || _isShareSheetOpen) return;
    setState(() => _isShareSheetOpen = true);
    final uploaded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ShareCardSheet(),
    );
    if (!mounted) return;
    setState(() => _isShareSheetOpen = false);
    if (uploaded == true) {
      final mapState = appRoutes.mapScreenKey.currentState;
      if (mapState != null) {
        try { (mapState as dynamic).refreshMap(); } catch (_) {}
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('소식이 업로드되었어요.')),
      );
    }
  }

  void _onItemTapped(int index) {
    // 가운데 버튼은 탭 전환 없이 공유하기 시트를 연다.
    if (index == 1) {
      _openShareSheet();
      return;
    }
    final current = _nav.selectedIndex.value;
    // 지도 탭(인덱스 0)을 이미 선택한 상태에서 다시 터치하면 새로고침
    if (index == 0 && current == 0) {
      final mapState = appRoutes.mapScreenKey.currentState;
      if (mapState != null) {
        try { (mapState as dynamic).refreshMap(); } catch (_) {}
      }
    }
    // My 탭(인덱스 2)을 이미 선택한 상태에서 다시 터치하면 새로고침
    else if (index == 2 && current == 2) {
      final profileState = appRoutes.profileScreenKey.currentState;
      if (profileState != null) {
        try { (profileState as dynamic).refreshProfile(); } catch (_) {}
      }
    } else {
      _nav.selectedIndex.value = index;
    }
  }

  static const _navItems = [
    {'icon': 'assets/icon/svg/map_icon.svg', 'activeIcon': 'assets/icon/svg/map_bold_icon.svg', 'label': '지도'},
    {'icon': 'assets/icon/svg/additem_icon.svg', 'activeIcon': 'assets/icon/svg/additem_bold_icon.svg', 'label': '공유하기'},
    {'icon': 'assets/icon/svg/user_icon.svg', 'activeIcon': 'assets/icon/svg/user_bold_icon.svg', 'label': 'My'},
  ];

  Widget _buildBottomNav(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border, width: 1)),
        boxShadow: [
          BoxShadow(color: colors.shadow, blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              // 가운데 버튼(공유하기)은 시트가 열려 있는 동안만 활성 표시.
              final isActive = index == 1
                  ? _isShareSheetOpen
                  : _nav.selectedIndex.value == index;
              final iconColor = isActive ? colors.primaryStrong : colors.textMuted;
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
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['label']!,
                        style: TextStyle(
                          color: iconColor,
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
        index: _stackIndexFor(_nav.selectedIndex.value),
        children: appRoutes.bottomNavigationPages(),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    ));
  }
}
