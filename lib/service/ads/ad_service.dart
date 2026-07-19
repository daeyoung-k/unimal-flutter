import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 광고(AdMob) 전역 서비스.
///
/// SDK 초기화와 광고 단위 ID 관리를 한 곳에 모은다.
/// 화면/위젯은 AdMob SDK를 직접 호출하지 않고 이 서비스만 참조한다.
/// → 개편된 화면에도 위젯만 떨구면 붙고, ID 교체는 .env 한 곳에서 끝난다.
class AdService extends GetxService {
  static AdService get to => Get.find<AdService>();

  /// MobileAds SDK 초기화. main()에서 Get.putAsync로 1회 호출.
  Future<AdService> init() async {
    await MobileAds.instance.initialize();
    return this;
  }

  /// 플랫폼별 배너 광고 단위 ID.
  ///
  /// - **release 빌드(=출시)**: .env(.prod)의 실제 ID 사용 → 실제 광고, "Test Ad" 라벨 없음.
  /// - **debug/profile 빌드**: 항상 구글 테스트 ID 사용 → 테스트 광고.
  ///   (개발 중 실제 광고를 잘못 클릭하면 계정이 정지될 수 있어 빌드 모드로 강제 분리.)
  String get bannerUnitId {
    if (!kReleaseMode) {
      return Platform.isIOS ? _testBannerIos : _testBannerAndroid;
    }
    if (Platform.isIOS) {
      return dotenv.env['ADMOB_BANNER_IOS'] ?? _testBannerIos;
    }
    return dotenv.env['ADMOB_BANNER_ANDROID'] ?? _testBannerAndroid;
  }

  // 구글 공식 테스트 배너 ID (폴백 — 실 ID 누락 시에도 안전하게 테스트 광고 노출)
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos =
      'ca-app-pub-3940256099942544/2934735716';
}
