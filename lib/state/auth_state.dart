import 'package:get/get.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/state/secure_storage.dart';

class AuthState extends GetxController {
    final SecureStorage secureStorage;

    AuthState({required this.secureStorage});

    var loginMethod = LoginType.none.obs;
    var accessToken = ''.obs;
    var refreshToken = ''.obs;
    var email = ''.obs;
    var fcmToken = ''.obs;

    bool get isLoggedIn =>
        accessToken.value.isNotEmpty &&
        accessToken.value != 'null' &&
        refreshToken.value.isNotEmpty &&
        refreshToken.value != 'null';

    Future<void> loadTokens() async {
      final access = await secureStorage.getAccessToken();
      final refresh = await secureStorage.getRefreshToken();
      final loginMethodString = await secureStorage.getLoginMethod();
      final userEmail = await secureStorage.getEmail();

      accessToken.value = access ?? '';
      refreshToken.value = refresh ?? '';
      loginMethod.value = LoginType.from(loginMethodString ?? "");
      email.value = userEmail ?? '';
    }

    Future<void> setTokens(String access, String refresh, String userEmail, LoginType method) async {
      accessToken.value = access;
      refreshToken.value = refresh;
      email.value = userEmail;
      loginMethod.value = method;
      
      await secureStorage.saveEmail(userEmail);
      await secureStorage.saveAccessToken(access);
      await secureStorage.saveRefreshToken(refresh);
      await secureStorage.saveLoginMethod(method.name);
    }

    Future<void> clearTokens() async {
      await secureStorage.deleteAccessToken();
      await secureStorage.deleteRefreshToken();
      await secureStorage.deleteLoginMethod();
      await secureStorage.deleteEmail();

      accessToken.value = '';
      refreshToken.value = '';
      email.value = '';
      loginMethod.value = LoginType.none;
    }

    Future<void> setFCMToken(String fcmToken) async {
      this.fcmToken.value = fcmToken;
      await secureStorage.saveFCMToken(fcmToken);
    }

    Future<String?> getFCMToken() async {
      return await secureStorage.getFCMToken();
    }
}
