
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/add_item.dart';
import 'package:unimal/screens/auth/id_find.dart';
import 'package:unimal/screens/auth/password_find.dart';
import 'package:unimal/screens/auth/signup.dart';
import 'package:unimal/screens/detail_board/detail_board.dart';
import 'package:unimal/screens/board/board.dart';
import 'package:unimal/screens/auth/login/login.dart';
import 'package:unimal/screens/map/map.dart';
import 'package:unimal/screens/navigation/root_screen.dart';
import 'package:unimal/screens/auth/tel_verification.dart';
import 'package:unimal/screens/profile.dart';
class AppRoutes {
  // 게시판 화면의 GlobalKey (새로고침을 위해 사용)
  // State 타입을 명시적으로 지정하기 위해 dynamic 사용
  final GlobalKey boardScreenKey = GlobalKey();
  // 지도 화면의 GlobalKey (새로고침을 위해 사용)
  final GlobalKey mapScreenKey = GlobalKey();

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
      GetPage(name: '/board', page: () => RootScreen(selectedIndex: 2)),
      GetPage(name: '/mypage', page: () => RootScreen(selectedIndex: 3)),
    ];
  }
  
  List<GetPage> _authRoutes() {
    return [
      GetPage(name: '/login', page: () => LoginScreens()),
      GetPage(name: '/tel-verification', page: () => TelVerificationScreen()),
      GetPage(name: '/id-find', page: () => IdFindScreen()),
      GetPage(name: '/password-find', page: () => PasswordFindScreen()),
      GetPage(name: '/signup', page: () => SignupScreens()),
      GetPage(name: '/detail-board', page: () => DetailBoardScreen()),
    ];
  }

  // 하단 네비게이션 바 아이템 (getter로 변경하여 boardScreenKey 사용 가능)
  List<Map<String, dynamic>> get _bottomNavigationItems => [
    {
      "page": MapScreens(key: mapScreenKey),
      "bottomNavigationIcon": BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/map_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/map_bold_icon.svg'),
        label: '지도')
    },
    {
      "page": AddItemScreens(),
      "bottomNavigationIcon": BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/additem_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/additem_bold_icon.svg'),
        label: '공유하기')
    },
    {
      "page": BoardScreens(key: boardScreenKey),
      "bottomNavigationIcon": BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/clipboard_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/clipboard_bold_icon.svg'),
        label: '게시판')
    },
    {
      "page": ProfileScreens(),
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