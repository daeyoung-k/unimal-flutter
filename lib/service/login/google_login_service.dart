import 'dart:io';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleLoginService {  
  Future<void> login() async {
    try {
      var response = await _googleSignIn.signIn();
      var body = jsonEncode({
              "provider": "GOOGLE",
              "email": response!.email,
              "name": response.displayName
            });
      
      var host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      var headers = {"Content-Type": "application/json;charset=utf-8"};
      var url = Uri.http('${host}:8080', 'user/auth/login/mobile/google');
      var res = await http.post(url, headers: headers, body: body);
      
      print(res.body);
      
      
    } catch (error) {
      print("구글 로그인 오류 - ${error.toString()}");
      
    }
  }
}

const List<String> scopes = <String>[
  'email',
  'https://www.googleapis.com/auth/contacts.readonly',
  'https://www.googleapis.com/auth/userinfo.profile',
];

GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: scopes,
);