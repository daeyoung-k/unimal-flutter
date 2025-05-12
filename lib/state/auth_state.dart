import 'package:get/get.dart';
import 'package:unimal/state/secure_storage.dart';

class AuthState extends GetxController {
    final SecureStorage secureStorage;

    AuthState({required this.secureStorage});

    var provider = ''.obs;
    var accessToken = ''.obs;
    var refreshToken = ''.obs;

    Future<void> loadTokens() async {
      final access = await secureStorage.getAccessToken();
      final refresh = await secureStorage.getRefreshToken();
      final providerType = await secureStorage.getProvider();

      accessToken.value = access ?? '';
      refreshToken.value = refresh ?? '';
      provider.value = providerType ?? '';
    }

    Future<void> setTokens(String access, String refresh, String providerType) async {
      accessToken.value = access;
      refreshToken.value = refresh;
      provider.value = providerType;

      await secureStorage.saveAccessToken(access);
      await secureStorage.saveRefreshToken(refresh);
      await secureStorage.saveProvider(providerType);
    }

    bool get isLoginChecked => accessToken.value.isNotEmpty;
}