import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:unimal/screens/board/widget/photo_arrow.dart';

class DetailImages extends StatefulWidget {
  final List<String> imageUrls;
  final double screenHeight;

  const DetailImages({
    super.key,
    required this.imageUrls,
    required this.screenHeight,
  });

  @override
  State<DetailImages> createState() => _DetailImagesState();
}

class _DetailImagesState extends State<DetailImages> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Container(
                color: const Color(0xFF1A1A2E),
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrls[index],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[100],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF7AB3FF),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[100],
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                    ),
                  ),
                  imageBuilder: (context, imageProvider) =>
                      Image(image: imageProvider, fit: BoxFit.contain, width: double.infinity),
                ),
              );
            },
          ),
          if (_currentPage > 0)
            PhotoArrow(pageController: _pageController, direction: "previous"),
          if (_currentPage < widget.imageUrls.length - 1)
            PhotoArrow(pageController: _pageController, direction: "next"),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.imageUrls.length, (i) {
                  final bool active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
