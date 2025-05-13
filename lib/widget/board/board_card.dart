import 'package:flutter/material.dart';

class BoardCard extends StatelessWidget {
  const BoardCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 360,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 4,
                offset: Offset(0, 4),
                spreadRadius: 0,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 360,
                height: 250,
                decoration: ShapeDecoration(
                  color: const Color(0xFFD9D9D9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                ),
              ),
              Container(
                width: 384,
                height: 348,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage("https://play-lh.googleusercontent.com/rKTBYD8ykwgfHN_nFSwUErjQRPGjSEkStsjNQSUvgYGaEURpC2DMR7_1OdPu_dzysErv=w480-h960-rw"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                height: 96,
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 62,
                      top: 70,
                      child: Container(
                        width: 236.89,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 124,
                          children: [
                            SizedBox(
                              width: 39.16,
                              child: Text(
                                '좋아요',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(width: 20, height: 20, child: Stack()),
                            SizedBox(
                              width: 26.11,
                              child: Text(
                                '댓글',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(width: 20, height: 20, child: Stack()),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 5,
                      child: Container(
                        width: 125,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 125,
                              child: Text(
                                '식빵굽는다',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 17,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '#고양이',
                              style: TextStyle(
                                color: const Color(0xFFB8BFC8),
                                fontSize: 10,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              '#미세',
                              style: TextStyle(
                                color: const Color(0xFFB8BFC8),
                                fontSize: 10,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(
                              width: 125,
                              child: Text(
                                '서울 광진구 아차산로 55길 81',
                                style: TextStyle(
                                  color: const Color(0xFF757575),
                                  fontSize: 10,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w400,
                                  height: 1.60,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
