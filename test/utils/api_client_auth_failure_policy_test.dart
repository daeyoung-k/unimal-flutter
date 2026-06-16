import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('api client separates interactive and silent auth expiration handling', () {
    final source = File('lib/utils/api_client.dart').readAsStringSync();

    expect(source, contains('enum AuthFailurePolicy'));
    expect(source, contains('AuthFailurePolicy.interactive'));
    expect(source, contains('silent,'));
    expect(source, contains('authFailurePolicy == AuthFailurePolicy.interactive'));
    expect(source, contains('pageMovingWithshowTextAlert'));
  });

  test('token reissue does not clear local auth on transient failures', () {
    final source = File('lib/service/login/account_service.dart').readAsStringSync();

    expect(source, contains('enum TokenReissueResult'));
    expect(source, contains('TokenReissueResult.unavailable'));
    expect(source, contains('clearOnAuthExpired'));
    expect(source, isNot(contains('catch (error) {\n      stateClear();')));
  });

  test('device sync uses silent auth failure policy', () {
    final source = File('lib/service/user/user_info_service.dart').readAsStringSync();

    expect(source, contains('authFailurePolicy: AuthFailurePolicy.silent'));
  });

  test('push sync checks stable login state before background device sync', () {
    final source = File('lib/service/push/push_notification_service.dart').readAsStringSync();

    expect(source, contains('authState.isLoggedIn'));
    expect(source, isNot(contains('authState.accessToken.value.isNotEmpty')));
  });
}
