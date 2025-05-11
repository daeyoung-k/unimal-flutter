import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk_common.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:unimal/screens/navigation/root_screen.dart';
import 'package:unimal/screens/login.dart';
import 'package:unimal/screens/map.dart';
import 'package:unimal/state/secure_storage.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");

  final kakaoAppKey = dotenv.env['KAKAO_APP_KEY'];
  KakaoSdk.init(
    nativeAppKey: kakaoAppKey,
  );

  final naverLoginIosUrlscheme = dotenv.env['NAVER_LOGIN_IOS_URL_SCHEME']!;
  final naverLoginClientId = dotenv.env['NAVER_LOGIN_CLIENT_ID']!;
  final naverLoginClientSecret = dotenv.env['NAVER_LOGIN_CLIENT_SECRET']!;
  final naverLoginClientName = dotenv.env['NAVER_LOGIN_CLIENT_NAME']!;
  NaverLoginSDK.initialize(
      urlScheme: naverLoginIosUrlscheme,
      clientId: naverLoginClientId,
      clientSecret: naverLoginClientSecret,
      clientName: naverLoginClientName);

  // WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  Get.put(SecureStorage());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        home: RootScreen(),
    );
  }
}
