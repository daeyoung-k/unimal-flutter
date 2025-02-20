import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:unimal/screens/add_item.dart';
import 'package:unimal/screens/board.dart';
import 'package:unimal/screens/map.dart';
import 'package:unimal/screens/profile.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<StatefulWidget> createState() => _RootScreen();
}

class _RootScreen extends State<RootScreen> {

  int _selectedIndex = 0;

  final List<Widget> _pages = [
    MapScreens(),                   // 지도 페이지
    AddItemScreens(),               // 아이템 추가 페이지
    BoardScreens(),                 // 게시판 페이지
    ProfileScreens(),               // 프로필 페이지
  ];

  final List<BottomNavigationBarItem> _icons = [
    BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/map_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/map_bold_icon.svg'),
        label: 'Map'),
    BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/additem_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/additem_bold_icon.svg'),
        label: 'Add'),
    BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/clipboard_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/clipboard_bold_icon.svg'),
        label: 'Board'),
    BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/user_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/user_bold_icon.svg'),
        label: 'Profile'),
  ];


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
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: _icons,
        selectedItemColor: Color(0xFF4D91FF),
        unselectedItemColor: Colors.black,
        showUnselectedLabels: true,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
    
  }
}
