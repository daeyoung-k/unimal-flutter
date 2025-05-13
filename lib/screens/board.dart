import 'dart:io';

import 'package:flutter/material.dart';
import 'package:unimal/widget/board/board_card.dart';
import 'package:unimal/widget/board/board_search.dart';

class BoardScreens extends StatefulWidget {
  const BoardScreens({super.key});

  @override
  State<BoardScreens> createState() => _BoardScreensState();
}

class _BoardScreensState extends State<BoardScreens> {
  bool _isSearchFocused = false;

  @override
  Widget build(BuildContext context) {
    double topMargin = Platform.isAndroid ? 20 : 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 235, 235, 235),
        body: SafeArea(
            child: Center(
                child: Column(
          children: [
            Padding(padding: EdgeInsets.only(top: topMargin)),
            BoardSearch(
              onFocusChange: (focused) {
                setState(() {
                  _isSearchFocused = focused;
                });
              },
            ),
            Padding(padding: EdgeInsets.only(top: 10)),
            if (!_isSearchFocused) ...[
              BoardCard()
            ]
          ],
        ))),
      ),
    );
  }
}
