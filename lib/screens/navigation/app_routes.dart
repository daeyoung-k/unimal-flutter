
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/add/add_item.dart';
import 'package:unimal/screens/board/edit_board/edit_board.dart';
import 'package:unimal/screens/auth/id_find.dart';
import 'package:unimal/screens/auth/password_find.dart';
import 'package:unimal/screens/auth/signup.dart';
import 'package:unimal/screens/board/detail_board/detail_board.dart';
import 'package:unimal/screens/board/board.dart';
import 'package:unimal/screens/auth/login/login.dart';
import 'package:unimal/screens/map/map_naver.dart';
import 'package:unimal/screens/navigation/root_screen.dart';
import 'package:unimal/screens/auth/tel_verification.dart';
import 'package:unimal/screens/profile/profile.dart';
import 'package:unimal/screens/profile/setting/notice/notice_list.dart';
import 'package:unimal/screens/web/web_view_screen.dart';
class AppRoutes {
  final GlobalKey mapScreenKey = GlobalKey();
  final GlobalKey profileScreenKey = GlobalKey();
  final GlobalKey addItemScreenKey = GlobalKey();

  List<GetPage> pages() {
    return [
      ..._rootRoutes(),
      ..._authRoutes(),
    ];
  }

  List<GetPage> _rootRoutes() {
    return [
      GetPage(name: '/map', page: () => RootScreen(selectedIndex: 0)),
      GetPage(name: '/add', page: () => RootScreen(selectedIndex: 1)),
      GetPage(name: '/mypage', page: () => RootScreen(selectedIndex: 2)),
    ];
  }

  List<GetPage> _authRoutes() {
    return [
      GetPage(name: '/login', page: () => LoginScreens()),
      GetPage(name: '/tel-verification', page: () => TelVerificationScreen()),
      GetPage(name: '/id-find', page: () => IdFindScreen()),
      GetPage(name: '/password-find', page: () => PasswordFindScreen()),
      GetPage(name: '/signup', page: () => SignupScreens()),
      GetPage(name: '/board', page: () => BoardScreens()),
      GetPage(name: '/detail-board', page: () => DetailBoardScreen()),
      GetPage(name: '/edit-board', page: () => EditBoardScreen()),
      GetPage(name: '/notice-list', page: () => const NoticeListScreen()),
      GetPage(name: '/webview', page: () => const WebViewScreen()),
    ];
  }

  // 하단 네비게이션 바 아이템
  List<Map<String, dynamic>> get _bottomNavigationItems => [
    {
      "page": MapNaverScreens(key: mapScreenKey),
      "bottomNavigationIcon": BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/map_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/map_bold_icon.svg'),
        label: '지도')
    },
    {
      "page": AddItemScreens(key: addItemScreenKey),
      "bottomNavigationIcon": BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/additem_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/additem_bold_icon.svg'),
        label: '공유하기')
    },
    {
      "page": ProfileScreens(key: profileScreenKey),
      "bottomNavigationIcon": BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/user_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/user_bold_icon.svg'),
        label: 'My')
    },
  ];

  List<Widget> bottomNavigationPages() {
    return _bottomNavigationItems.map((item) => item["page"] as Widget).toList();
  }

  List<BottomNavigationBarItem> bottomNavigationIcons() {
   return _bottomNavigationItems.map((item) => item["bottomNavigationIcon"] as BottomNavigationBarItem).toList();
  }
}
