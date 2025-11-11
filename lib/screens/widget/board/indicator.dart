
import 'package:flutter/material.dart';

class Indicator extends StatefulWidget {
  final List<String> images;
  final int currentPage;
  const Indicator({super.key, required this.images, required this.currentPage});

  @override
  State<Indicator> createState() => _IndicatorState();
}

class _IndicatorState extends State<Indicator> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.images.length, (index) {
          return Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.currentPage == index
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
            ),
          );
        }),
      ),
    );
  }
  
}