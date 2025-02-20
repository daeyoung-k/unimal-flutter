import 'package:flutter/material.dart';

class BoardScreens extends StatelessWidget {
  const BoardScreens({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 48, 61, 81),
      body: Center(child: Text("게시판 페이지"),),
    );
  }
}
