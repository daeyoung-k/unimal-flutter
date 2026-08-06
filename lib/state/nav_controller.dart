import 'package:get/get.dart';

class NavController extends GetxController {
  final selectedIndex = 0.obs;
  final pendingMapLat = Rx<double?>(null);
  final pendingMapLng = Rx<double?>(null);

  /// 지도로 포커스할 게시글 id.
  ///
  /// 좌표만으로는 어떤 글인지 알 수 없어 마커를 찾아 바텀카드를 열 수 없다.
  /// null 이면 좌표 이동만 한다(구 동작). 지도 화면은 pendingMapLat 변화를
  /// 트리거로 삼으므로, 이 값은 반드시 pendingMapLat **보다 먼저** 세팅해야 한다.
  final pendingMapBoardId = Rx<String?>(null);

  /// 공유하기 시트 열기 요청 이벤트. RootScreen 이 구독해 시트를 띄운다.
  /// 값 자체는 의미 없고 증가가 트리거다.
  final shareSheetRequest = 0.obs;

  void requestShareSheet() => shareSheetRequest.value++;
}
