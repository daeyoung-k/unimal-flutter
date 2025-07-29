import 'package:flutter/material.dart';
import 'package:unimal/screens/board/widget/indicator.dart';
import 'package:unimal/screens/board/widget/photo_arrow.dart';

class BoardCardImage extends StatefulWidget {
  final double screenHeight;
  final List<String> imageUrls;

  const BoardCardImage({
    super.key, 
    required this.screenHeight, 
    required this.imageUrls
  });
  
  @override
  State<BoardCardImage> createState() => _BoardCardImageState();
}

class _BoardCardImageState extends State<BoardCardImage> {

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override 
  void dispose() {
      _pageController.dispose();
      super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.screenHeight * 0.4,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
                return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                        decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFB8BFC8)),
                            image: DecorationImage(
                                image: NetworkImage(widget.imageUrls[index]),
                                fit: BoxFit.fill
                            ),
                        ),
                    ),
                );
            }
          ),
          if (_currentPage > 0) PhotoArrow(pageController: _pageController, direction: "previous"),
          if (_currentPage < widget.imageUrls.length - 1) PhotoArrow(pageController: _pageController, direction: "next"),
          Indicator(images: widget.imageUrls, currentPage: _currentPage,),      
        ],
      ),
      
    );
  }
}