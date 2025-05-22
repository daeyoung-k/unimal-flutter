import 'package:flutter/material.dart';
import 'package:unimal/widget/board/board_card_content.dart';
import 'package:unimal/widget/board/indicator.dart';
import 'package:unimal/widget/board/photo_arrow.dart';

class BoardCard extends StatefulWidget {
  const BoardCard({super.key});

  @override
  State<BoardCard> createState() => _BoardCardState();

  
  
}

class _BoardCardState extends State<BoardCard> {
  final List<String> imageUrls = [
      "https://play-lh.googleusercontent.com/rKTBYD8ykwgfHN_nFSwUErjQRPGjSEkStsjNQSUvgYGaEURpC2DMR7_1OdPu_dzysErv=w480-h960-rw",
      "https://search.pstatic.net/common/?src=http%3A%2F%2Fblogfiles.naver.net%2FMjAyNTAxMDFfMTgz%2FMDAxNzM1NzQyODU3NDUy.aVNDa7g0PLGGmPc4kVSIXWlagMUEqVzSiengkZa78g4g._PD32APBUvDV75GSx3mXowmrIjIqaGWxGvm4sOvy3ngg.JPEG%2FIMG_1553.JPG&type=sc960_832",
      "https://search.pstatic.net/common/?src=http%3A%2F%2Fblogfiles.naver.net%2FMjAyMTA1MjBfMjcy%2FMDAxNjIxNTIwNjQ3NjQy.aOBFYTd9GLD_C5KXLVN4EGRUrUKhQIl8Rg46oo15RGgg.RH2tVY4NMuR9l90ucuyGx3kh5_KOQROzHze9akTGIG0g.JPEG.hjincity%2FIMG_0478.JPG&type=sc960_832"
  ];
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override 
  void dispose() {
      _pageController.dispose();
      super.dispose();
  }

        
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    final String content = 'Instagram 소라고둥님에게 소원을 빌어봐요! 귀여운 고양이와 강아지를 만날 수 있어요! '
    '지금 근처에 있는 동물들을 찾아보세요! 🐶🐱 아주 많은 이야기들이 있습니다~!! 🐾';

    return SizedBox(
      width: screenWidth * 0.98,      
      child: Column(
        children: [
          SizedBox(
            height: screenHeight * 0.06,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '닉네임',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Text(
                        '위치',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          SizedBox(
            height: screenHeight * 0.4,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: imageUrls.length,
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
                                      image: NetworkImage(imageUrls[index]),
                                      fit: BoxFit.fill
                                  ),
                              ),
                          ),
                      );
                  }
                ),
                if (_currentPage > 0) PhotoArrow(pageController: _pageController, direction: "previous"),
                if (_currentPage < imageUrls.length - 1) PhotoArrow(pageController: _pageController, direction: "next"),
                Indicator(images: imageUrls, currentPage: _currentPage,),      
              ],
            ),
            
          ),
          BoardCardContent(content: content),
        ],
      )
    );
  }

}