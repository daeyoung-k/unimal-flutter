import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class BottomNavigationWidget extends StatefulWidget {
  const BottomNavigationWidget({super.key});

  @override
  State<StatefulWidget> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigationWidget> {

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: [
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
      ],
      selectedItemColor: Color(0xFF4D91FF),
      unselectedItemColor: Colors.black,
      showUnselectedLabels: true,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
    );
  }
}
