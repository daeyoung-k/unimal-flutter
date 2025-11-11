
import 'package:flutter/material.dart';

class PhotoArrow extends StatefulWidget {
  final PageController pageController;
  final String direction;
  const PhotoArrow({super.key, required this.pageController, required this.direction});

  @override
  State<PhotoArrow> createState() => _PhotoArrowState();

}

class _PhotoArrowState extends State<PhotoArrow> {
  @override
  Widget build(BuildContext context) {

    final bool isNext = widget.direction == "next";
    final IconData icon = isNext ? Icons.arrow_forward_ios : Icons.arrow_back_ios;
    
    return Positioned(
      left: isNext ? null : 3.0,
      right: isNext ? 3.0 : null,
      top: 0,
      bottom: 0,
      child: Center(
        child: IconButton(
          icon: Icon(icon, color: Colors.white.withValues(alpha: 0.6)),
          onPressed: () => {
            if (isNext) {
              widget.pageController.nextPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              )
            } else {
              widget.pageController.previousPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              )
            }
          },
        ),
      ),
    );
  }
  
}