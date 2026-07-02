import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:unimal/service/map/naver_map_service.dart';
import 'package:unimal/service/ads/ad_service.dart';
import 'package:get/get.dart';
import 'package:unimal/firebase_options.dart';
import 'package:unimal/screens/navigation/root_screen.dart';
import 'package:unimal/screens/auth/login/login.dart';
import 'package:unimal/screens/navigation/app_routes.dart';
import 'package:unimal/service/auth/permission_service.dart';
import 'package:unimal/service/auth/update_check_service.dart';
import 'package:unimal/service/login/kakao_login_service.dart';
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
}

/// flutter_naver_map 이미지 캐시(fnm1_img) 삭제.
/// 실패해도 앱 동작에는 지장 없으므로 로깅만 하고 넘어간다.
Future<void> _clearNaverMapImageCache() async {
  try {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}${Platform.pathSeparator}fnm1_img');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      debugPrint('[naverMap] 마커 이미지 캐시 정리 완료');
    }
  } catch (e) {
    debugPrint('[naverMap] 마커 이미지 캐시 정리 실패(무시): $e');
  }
}

Future<void> main() async {
  // Flutter 바인딩 초기화 (비동기 작업 전에 필수)
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // flutter_naver_map 클러스터 마커의 Android race로 인한 비동기 PlatformException
  // ("overlay can't found")은 setIcon 등이 내부적으로 await되지 않아 우리 try/catch
  // 밖에서 '미처리'로 떠오른다. 디버그에서 '미처리 예외 중단'이 켜져 있으면 이때 메인
  // 스레드가 멈춰 ANR처럼 보인다. 데이터상 비치명적이므로 이 예외만 로깅 후 흡수하고,
  // 그 외 에러는 기존대로 전파해 진짜 버그를 숨기지 않는다.
  widgetsBinding.platformDispatcher.onError = (error, stack) {
    if (error is PlatformException &&
        (error.message?.contains("overlay can't found") ?? false)) {
      debugPrint('[naverMap] 무시된 오버레이 race: ${error.message}');
      return true; // 처리됨 — 전파/중단 막음
    }
    return false; // 그 외는 평소대로 처리되도록
  };

  // Firebase 초기화 (다른 초기화 작업보다 먼저 수행)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
  // 백그라운드 메시지 핸들러 등록 (Firebase 초기화 후 바로 설정)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 환경변수 로드
  const environment = String.fromEnvironment('ENV', defaultValue: 'local');
  await dotenv.load(fileName: ".env.$environment");

  // 카카오 로그인 SDK 초기화
  KakaoLoginService().kakaoInit();
  // 네이버 로그인 SDK 초기화
  NaverLoginService().naverInit();

  // flutter_naver_map 마커 이미지 캐시 정리 — 플러그인이 마커 이미지를
  // 임시 PNG 파일로 캐싱하는데, 쓰기 경합으로 0바이트 파일이 남으면 iOS
  // 네이티브가 강제 언래핑하다 크래시한다(플러그인 이슈 #251, 1.4.4 미해결).
  // 시작 시 캐시를 비워 깨진 파일이 재사용되지 않게 한다.
  await _clearNaverMapImageCache();

  // 네이버 지도 초기화
  await NaverMapService().naverMapInit();

  // AdMob(광고) SDK 초기화 — GetX에 등록하며 1회 초기화.
  // 이후 화면에서는 AdService.to / const AdBanner() 로만 광고에 접근.
  await Get.putAsync<AdService>(() => AdService().init());

  // 상태관리 초기화 (토큰 로드 완료까지 대기)
  final authState = await StateInit().stateInit();

  // 알림 권한 요청 (위치 권한은 각 화면에서 geolocator를 통해 처리)
  await PermissionService().requestNotificationPermission();

  // 푸시 알림 초기화 + 업데이트 체크는 runApp() 이후 위젯 트리가 준비된 뒤 실행.
  // runApp() 이전에 실행하면 ApiClient._refresh()가 네비게이터 없는 상태에서
  // Get.dialog()를 호출해 로그인 화면 위에 경고창이 뒤늦게 뜨는 문제가 있었음.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await PushNotificationService().initialize();
    final updateCheckService = UpdateCheckService();
    await updateCheckService.initialize();
    await updateCheckService.checkAndHandleUpdate();
  });

  // loadTokens() 완료 후 저장된 토큰이 있는지 확인
  runApp(MyApp(loginChecked: authState.isLoggedIn));

  FlutterNativeSplash.remove();
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ko', 'KR'),
    );
  }
}
// 
