import 'package:get/get.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/state/secure_storage.dart';

class AuthState extends GetxController {
    final SecureStorage secureStorage;

    AuthState({required this.secureStorage});

    var provider = LoginType.none.obs;
    var accessToken = ''.obs;
    var refreshToken = ''.obs;

    Future<void> loadTokens() async {
      final access = await secureStorage.getAccessToken();
      final refresh = await secureStorage.getRefreshToken();
      final loginTypeString = await secureStorage.getProvider();

      accessToken.value = access ?? '';
      refreshToken.value = refresh ?? '';
      provider.value = LoginType.from(loginTypeString ?? "");
    }

    Future<void> setTokens(String access, String refresh, LoginType loginType) async {
      accessToken.value = access;
      refreshToken.value = refresh;
      provider.value = loginType;

      await secureStorage.saveAccessToken(access);
      await secureStorage.saveRefreshToken(refresh);
      await secureStorage.saveProvider(loginType.name);
    }

    Future<void> clearTokens() async {
      await secureStorage.deleteAccessToken();
      await secureStorage.deleteRefreshToken();
      await secureStorage.deleteProvider();

      accessToken.value = '';
      refreshToken.value = '';
      provider.value = LoginType.none;
    }
}