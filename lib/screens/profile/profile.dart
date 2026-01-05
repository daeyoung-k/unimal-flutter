import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/state/auth_state.dart';

class ProfileScreens extends StatelessWidget {
  const ProfileScreens({super.key});

  @override
  Widget build(BuildContext context) {
    final logoutService = AccountService();
    final _authState = Get.find<AuthState>();
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 230, 40, 62),
      body: 
      Center(
        child: Row(children: [
          Text(_authState.provider.value.name),
          ElevatedButton(
            onPressed: () => logoutService.logout(),
            child: Text("로그아웃"),
          ),
          ElevatedButton(
            onPressed: () => logoutService.withdrawal(),
            child: Text("회원탈퇴"),
          ),

        ],)
      ),
    );
  }
}
