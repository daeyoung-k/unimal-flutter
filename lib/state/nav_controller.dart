import 'package:get/get.dart';

class NavController extends GetxController {
  final selectedIndex = 0.obs;
  final pendingMapLat = Rx<double?>(null);
  final pendingMapLng = Rx<double?>(null);
}
