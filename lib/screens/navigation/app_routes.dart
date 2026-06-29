
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/auth/id_find.dart';
import 'package:unimal/screens/auth/password_find.dart';
import 'package:unimal/screens/auth/signup.dart';
import 'package:unimal/screens/board/detail_board/detail_board.dart';
import 'package:unimal/screens/board/board.dart';
import 'package:unimal/screens/auth/login/login.dart';
import 'package:unimal/screens/map/map_naver.dart';
import 'package:unimal/screens/map/marker/text_marker_demo.dart';
import 'package:unimal/screens/navigation/root_screen.dart';
import 'package:unimal/screens/auth/tel_verification.dart';
import 'package:unimal/screens/profile/profile.dart';
import 'package:unimal/screens/profile/mypage/story_list.dart';
import 'package:unimal/screens/profile/mypage/my_story_map_screen.dart';
import 'package:unimal/screens/profile/setting/notice/notice_list.dart';
import 'package:unimal/screens/web/web_view_screen.dart';
class AppRoutes {
  final GlobalKey mapScreenKey = GlobalKey();
  final GlobalKey profileScreenKey = GlobalKey();

  List<GetPage> pages() {
    return [
      ..._rootRoutes(),
      ..._authRoutes(),
    ];
  }

  List<GetPage> _rootRoutes() {
    return [
      GetPage(name: '/map', page: () => RootScreen(selectedIndex: 0)),
      // 공유하기 탭 제거 — 딥링크 호환을 위해 지도 탭 진입 후 시트 자동 오픈.
      GetPage(name: '/add', page: () => RootScreen(selectedIndex: 0, openShareSheet: true)),
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
      GetPage(name: '/story-list', page: () => const StoryListScreen()),
      GetPage(name: '/my-story-map', page: () => const MyStoryMapScreen()),
      GetPage(name: '/notice-list', page: () => const NoticeListScreen()),
      GetPage(name: '/webview', page: () => const WebViewScreen()),
      // 텍스트 마커 데모 (프론트 전용 · 목 데이터). Get.toNamed('/text-marker-demo')
      GetPage(
          name: '/text-marker-demo',
          page: () => const TextMarkerDemoScreen()),
    ];
  }

  /// 하단 네비게이션 스택 페이지.
  /// 네비 아이템은 3개(지도/공유하기/My)지만 공유하기는 액션 버튼(시트)이라
  /// 스택 페이지는 2개다. (탭 0 → 스택 0, 탭 2 → 스택 1)
  List<Widget> bottomNavigationPages() {
    return [
      MapNaverScreens(key: mapScreenKey),
      ProfileScreens(key: profileScreenKey),
    ];
  }
}
