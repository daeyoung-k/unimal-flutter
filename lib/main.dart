import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/navigation/root_screen.dart';
import 'package:unimal/screens/login.dart';
import 'package:unimal/service/login/kakao_login_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/service/login/naver_login_service.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/state/state_init.dart';

Future<void> main() async {
  // 카카오 로그인 SDK 초기화
  KakaoLoginService().kakaoInit();
  // 네이버 로그인 SDK 초기화
  NaverLoginService().naverInit();
  // 상태관리 초기화
  StateInit().stateInit();

  final authState = Get.find<AuthState>();
  final provider = authState.provider;

  // WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(MyApp(loginChecked: provider.value != LoginType.none));
}

class MyApp extends StatelessWidget {
  final bool loginChecked;
  const MyApp({super.key, this.loginChecked = false});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      getPages: [
        GetPage(name: '/login', page: () => LoginScreens()),
        GetPage(name: '/map', page: () => RootScreen(selectedIndex: 0)),
        GetPage(name: '/search', page: () => RootScreen(selectedIndex: 1)),
        GetPage(name: '/board', page: () => RootScreen(selectedIndex: 2)),
        GetPage(name: '/mypage', page: () => RootScreen(selectedIndex: 3)),
      ],
      home: loginChecked ? RootScreen() : LoginScreens(),
    );
  }
}
