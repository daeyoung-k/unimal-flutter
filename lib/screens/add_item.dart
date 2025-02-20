import 'package:flutter/material.dart';

class AddItemScreens extends StatelessWidget {
  const AddItemScreens({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 151, 177, 85),
      body: Center(child: Text("아이템 추가 페이지"),),
    );
  }
}
