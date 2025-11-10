import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/%08map/marker/marker_preview.dart';
import 'package:unimal/screens/board/detail_board.dart';
import 'package:unimal/screens/navigation/root_screen.dart';
import 'package:unimal/screens/auth/login/login.dart';
import 'package:unimal/screens/navigation/app_routes.dart';
import 'package:unimal/service/login/kakao_login_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/service/login/naver_login_service.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/state/state_init.dart';

Future<void> main() async {
  // ?ôòÍ≤ΩÎ???àò Î°úÎìú
  const environment = String.fromEnvironment('ENV', defaultValue: 'local');
  await dotenv.load(fileName: ".env.$environment");
  // Ïπ¥Ïπ¥?ò§ Î°úÍ∑∏?ù∏ SDK Ï¥àÍ∏∞?ôî
  KakaoLoginService().kakaoInit();
  // ?Ñ§?ù¥Î≤? Î°úÍ∑∏?ù∏ SDK Ï¥àÍ∏∞?ôî
  NaverLoginService().naverInit();
  // ?ÉÅ?ÉúÍ¥?Î¶? Ï¥àÍ∏∞?ôî
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
      getPages: AppRoutes().pages(),
      // home: loginChecked ? RootScreen() : DetailBoardScreen(),
      // home: loginChecked ? RootScreen() : RootScreen(selectedIndex: 2),
      // home: MarkerPreview(),
    );
  }
}
// 