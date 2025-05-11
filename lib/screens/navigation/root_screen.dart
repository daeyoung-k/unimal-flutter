import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:unimal/screens/board.dart';
import 'package:unimal/screens/login.dart';
import 'package:unimal/screens/map.dart';
import 'package:unimal/screens/profile.dart';
import 'package:unimal/screens/search.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key, this.selectedIndex = 0});

  final int selectedIndex;

  @override
  State<StatefulWidget> createState() => _RootScreen();
}

class _RootScreen extends State<RootScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  final List<Widget> _pages = [
    MapScreens(), // 지도 페이지
    SearchScreens(), // 검색 페이지
    BoardScreens(), // 게시판 페이지
    LoginScreens(), // 로그인 페이지
    // ProfileScreens(),               // 프로필 페이지
  ];

  final List<BottomNavigationBarItem> _icons = [
    BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/map_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/map_bold_icon.svg'),
        label: '지도'),
    BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/search_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/search_bold_icon.svg'),
        label: '검색'),
    BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/clipboard_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/clipboard_bold_icon.svg'),
        label: '게시판'),
    BottomNavigationBarItem(
        icon: SvgPicture.asset('assets/icon/svg/user_icon.svg'),
        activeIcon: SvgPicture.asset('assets/icon/svg/user_bold_icon.svg'),
        label: 'My'),
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
