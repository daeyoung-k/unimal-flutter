import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/state/auth_state.dart';


class LogoutService {
  final _authState = Get.find<AuthState>();

  Future<void> logout() async {
    var host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    var url = Uri.http('${host}:8080', 'user/auth/logout');
    var headers = {"Authorization": "Bearer ${_authState.refreshToken}"};
    var res = await http.get(url, headers: headers);
    var bodyData = jsonDecode(res.body);

    print("로그아웃 완료 ${bodyData}");

    _authState.clearTokens();
    
    Get.offAllNamed("/login");
  }


}