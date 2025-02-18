import 'package:flutter/material.dart';
import 'package:unimal/screens/home.dart';
import 'package:unimal/screens/login.dart';
import 'package:unimal/screens/Map.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MapScreens(),
    );
  }
}
