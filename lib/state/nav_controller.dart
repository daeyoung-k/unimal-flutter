import 'package:get/get.dart';

class NavController extends GetxController {
  final selectedIndex = 0.obs;
  final pendingMapLat = Rx<double?>(null);
  final pendingMapLng = Rx<double?>(null);

  /// 공유하기 시트 열기 요청 이벤트. RootScreen 이 구독해 시트를 띄운다.
  /// 값 자체는 의미 없고 증가가 트리거다.
  final shareSheetRequest = 0.obs;

  void requestShareSheet() => shareSheetRequest.value++;
}
