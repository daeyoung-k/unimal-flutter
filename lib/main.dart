import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk_common.dart';
import 'package:unimal/navigation/root_screen.dart';


Future<void> main() async {
  await dotenv.load(fileName: ".env");

  final kakaoAppKey = dotenv.env['KAKAO_APP_KEY'];
  KakaoSdk.init(nativeAppKey: kakaoAppKey,);
  
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
