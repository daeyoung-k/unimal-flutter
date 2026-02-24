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
    // 지도 탭(인덱스 0)을 이미 선택한 상태에서 다시 터치하면 새로고침
    if (index == 0 && _selectedIndex == 0) {
      // 지도 화면 새로고침
      final mapState = appRoutes.mapScreenKey.currentState;
      if (mapState != null) {
        try {
          (mapState as dynamic).refreshMap();
        } catch (e) {
          // 메서드가 없거나 호출 실패 시 무시
        }
      }
    }
    // 게시판 탭(인덱스 2)을 이미 선택한 상태에서 다시 터치하면 새로고침
    else if (index == 2 && _selectedIndex == 2) {
      // 게시판 화면 새로고침
      final boardState = appRoutes.boardScreenKey.currentState;
      if (boardState != null) {
        // refreshPosts 메서드가 있는지 확인하고 호출
        try {
          (boardState as dynamic).refreshPosts();
        } catch (e) {
          // 메서드가 없거나 호출 실패 시 무시
        }
      }
    }
    // My 탭(인덱스 3)을 이미 선택한 상태에서 다시 터치하면 새로고침
    else if (index == 3 && _selectedIndex == 3) {
      final profileState = appRoutes.profileScreenKey.currentState;
      if (profileState != null) {
        try {
          (profileState as dynamic).refreshProfile();
        } catch (e) {
          // 메서드가 없거나 호출 실패 시 무시
        }
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
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
