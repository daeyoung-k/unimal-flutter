import 'package:get/get.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/state/secure_storage.dart';

class AuthState extends GetxController {
    final SecureStorage secureStorage;

    AuthState({required this.secureStorage});

    var provider = LoginType.none.obs;
    var accessToken = ''.obs;
    var refreshToken = ''.obs;
    var email = ''.obs;

    Future<void> loadTokens() async {
      final access = await secureStorage.getAccessToken();
      final refresh = await secureStorage.getRefreshToken();
      final loginTypeString = await secureStorage.getProvider();
      final userEmail = await secureStorage.getEmail();

      accessToken.value = access ?? '';
      refreshToken.value = refresh ?? '';
      provider.value = LoginType.from(loginTypeString ?? "");
      email.value = userEmail ?? '';
    }

    Future<void> setTokens(String access, String refresh, String userEmail, LoginType loginType) async {
      accessToken.value = access;
      refreshToken.value = refresh;
      email.value = userEmail;
      provider.value = loginType;
      
      await secureStorage.saveEmail(userEmail);
      await secureStorage.saveAccessToken(access);
      await secureStorage.saveRefreshToken(refresh);
      await secureStorage.saveProvider(loginType.name);
    }

    Future<void> clearTokens() async {
      await secureStorage.deleteAccessToken();
      await secureStorage.deleteRefreshToken();
      await secureStorage.deleteProvider();
      await secureStorage.deleteEmail();

      accessToken.value = '';
      refreshToken.value = '';
      email.value = '';
      provider.value = LoginType.none;
    }
}