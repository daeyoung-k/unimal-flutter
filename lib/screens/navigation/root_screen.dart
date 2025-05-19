import 'package:flutter/material.dart';
import 'package:unimal/screens/navigation/app_routes.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key, this.selectedIndex = 0});

  final int selectedIndex;

  @override
  State<StatefulWidget> createState() => _RootScreen();
}

class _RootScreen extends State<RootScreen> {
  late int _selectedIndex;
  final appRoutes = AppRoutes();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: appRoutes.bottomNavigationPages(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: appRoutes.bottomNavigationIcons(),
        selectedItemColor: Color(0xFF4D91FF),
        unselectedItemColor: Colors.black,
        showUnselectedLabels: true,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
