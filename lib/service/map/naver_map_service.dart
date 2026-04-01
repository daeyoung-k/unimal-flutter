import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:logger/logger.dart';

class NaverMapService {
  var logger = Logger();

  Future<void> naverMapInit() async {
    await FlutterNaverMap().init(
      clientId: dotenv.env['NAVER_MAP_CLIENT_ID']!,
      onAuthFailed: (ex) {
        switch (ex) {
          case NQuotaExceededException(:final message):
            logger.e("사용량 초과 (message: $message)");
            break;
          case NUnauthorizedClientException() ||
              NClientUnspecifiedException() ||
              NAnotherAuthFailedException():
            logger.e("인증 실패: $ex");
            break;
        }
      },
    );
  }
}
