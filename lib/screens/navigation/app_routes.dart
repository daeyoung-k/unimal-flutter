
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/board.dart';
import 'package:unimal/screens/login.dart';
import 'package:unimal/screens/map.dart';
import 'package:unimal/screens/navigation/root_screen.dart';
import 'package:unimal/screens/profile.dart';
import 'package:unimal/screens/search.dart';

class AppRoutes {
  List<GetPage> pages() {
    return [
      GetPage(name: '/login', page: () => LoginScreens()),
      GetPage(name: '/map', page: () => RootScreen(selectedIndex: 0)),
      GetPage(name: '/add', page: () => RootScreen(selectedIndex: 1)),
      GetPage(name: '/board', page: () => RootScreen(selectedIndex: 2)),
      GetPage(name: '/mypage', page: () => RootScreen(selectedIndex: 3)),
    ];
  }


  final _bottomNavigationItems = [
    {
      "page": MapScreens(),
      "bottomNavigationIcon": BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/map_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/map_bold_icon.svg'),
        label: '지도')
    },
    {
      "page": SearchScreens(),
      "bottomNavigationIcon": BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/additem_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/additem_bold_icon.svg'),
        label: '글쓰기')
    },
    {
      "page": BoardScreens(),
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