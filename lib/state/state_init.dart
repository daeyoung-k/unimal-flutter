
import 'package:get/get.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/state/secure_storage.dart';

class StateInit {
  final _secureStorage = Get.put(SecureStorage());

  Future<void> stateInit() async {
    // 로그인 관련 상태관리
    _initAuth();
  }

  void _initAuth() {
    Get.put(AuthState(secureStorage: _secureStorage));
    final authState = Get.find<AuthState>();

    // 로그인 토큰 로드
    authState.loadTokens();
  }


}