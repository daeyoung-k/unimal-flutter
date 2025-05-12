import 'package:flutter/material.dart';
import 'package:unimal/service/login/logout_service.dart';

class ProfileScreens extends StatelessWidget {
  const ProfileScreens({super.key});

  @override
  Widget build(BuildContext context) {
    final logoutService = LogoutService();
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 230, 40, 62),
      body: Center(
        child: ElevatedButton(
          onPressed: () => logoutService.logout(),
          child: Text("로그아웃"),
        ),
      ),
    );
  }
}
