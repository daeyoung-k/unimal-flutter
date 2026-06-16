import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth state determines login from stored tokens, not provider', () {
    final source = File('lib/state/auth_state.dart').readAsStringSync();

    expect(source, contains('bool get isLoggedIn'));
    expect(source, contains('accessToken.value.isNotEmpty'));
    expect(source, contains('refreshToken.value.isNotEmpty'));
    expect(source, isNot(contains('provider.value = LoginType.from')));
  });

  test('secure storage keeps loginMethod and migrates legacy provider key', () {
    final source = File('lib/state/secure_storage.dart').readAsStringSync();

    expect(source, contains("write('loginMethod', loginMethod)"));
    expect(source, contains("read('loginMethod')"));
    expect(source, contains("read('provider')"));
    expect(source, contains("_storage.delete(key: 'provider')"));
  });
}
