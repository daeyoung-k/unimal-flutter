import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Unimal"),
      ),
      body: Container(
        child: Center(
          child: Text("Hello World"),
        ),
      ),
      bottomNavigationBar: Text("네비게이션"),
    );
  }
}
