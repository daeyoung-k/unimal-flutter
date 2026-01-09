import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:unimal/firebase_options.dart';
import 'package:unimal/screens/navigation/root_screen.dart';
import 'package:unimal/screens/auth/login/login.dart';
import 'package:unimal/screens/navigation/app_routes.dart';
import 'package:unimal/service/login/kakao_login_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/service/login/naver_login_service.dart';
import 'package:unimal/service/push/push_notification_service.dart';
import 'package:unimal/state/state_init.dart';

/// 백그라운드 메시지 핸들러
/// 
/// 앱이 백그라운드에 있을 때 수신된 메시지를 처리합니다.
/// 이 함수는 최상위 레벨에 있어야 합니다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase가 초기화되어 있어야 하므로 여기서는 로깅만 수행
  // 실제 처리는 PushNotificationService에서 수행됩니다.
  print('백그라운드에서 알림 수신: ${message.messageId}');
}

Future<void> main() async {
  // Flutter 바인딩 초기화 (비동기 작업 전에 필수)
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 초기화 (다른 초기화 작업보다 먼저 수행)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 백그라운드 메시지 핸들러 등록 (Firebase 초기화 후 바로 설정)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 환경변수 로드
  const environment = String.fromEnvironment('ENV', defaultValue: 'local');
  await dotenv.load(fileName: ".env.$environment");

  // 카카오 로그인 SDK 초기화
  KakaoLoginService().kakaoInit();
  // 네이버 로그인 SDK 초기화
  NaverLoginService().naverInit();

  // 상태관리 초기화 (토큰 로드 완료까지 대기)
  final authState = await StateInit().stateInit();
  final provider = authState.provider;

  // 푸시 알림 서비스 초기화
  await PushNotificationService().initialize();

  // WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // loadTokens() 완료 후 저장된 토큰이 있는지 확인
  runApp(MyApp(loginChecked: provider.value != LoginType.none));
}

class MyApp extends StatelessWidget {
  final bool loginChecked;
  const MyApp({super.key, this.loginChecked = false});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      getPages: AppRoutes().pages(),
      home: loginChecked ? RootScreen() : LoginScreens(),
      // home: loginChecked ? RootScreen() : DetailBoardScreen(),
    //   home: loginChecked ? RootScreen() : RootScreen(selectedIndex: 2),
      // home: MarkerPreview(),
    );
  }
}
// 