import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk_common.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:unimal/navigation/root_screen.dart';

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
    clientName: naverLoginClientName
  );

  // WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RootScreen(),
    );
  }
}
