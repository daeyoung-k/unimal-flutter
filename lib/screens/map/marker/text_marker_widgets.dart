import 'package:flutter/material.dart';

/// 텍스트 전용 커스텀 마커 위젯 모음.
///
/// 피그마 "텍스트 마커 v2 (대영 제안)" 기준.
/// - 줌인: [TextMarkerCard] — 흰 카드 + 제목 아이콘 + 본문 2줄 + 꼬리
/// - 줌아웃: [TextMarkerDot] — 원 글리프 + 제목 라벨
///
/// 사진 마커가 "원 안에 사진"이라면, 텍스트 마커는 "원 안에 텍스트 줄 글리프".
/// [TextGlyph] 모티프를 카드 제목 아이콘과 줌아웃 마커에 동일하게 써서
/// 줌 전환 시 "같은 글"이라는 연속성을 준다.
///
/// 이 위젯들은 `NOverlayImage.fromWidget(widget:, size:, context:)` 으로
/// 비트맵 변환해 네이버 지도 마커 아이콘으로 사용한다. Theme.extension 미정착
/// 상태라 색은 토큰 상수를 직접 참조한다 (off-tree 렌더 안정성).
class TextMarkerTokens {
  // app_colors.dart 라이트 토큰과 동기화.
  static const Color glyphBlue = Color(0xFF4D91FF); // primaryStrong
  static const Color badgeBlue = Color(0xFF3578E5); // primary
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFEEF0F3);
  static const Color divider = Color(0xFFEEF0F3);
  static const Color titleText = Color(0xFF1A1A2E); // textPrimary
  static const Color bodyText = Color(0xFF374151); // textSecondary
  static const Color shadow = Color(0x1F000000); // 12% black
}

/// 텍스트 줄 글리프가 들어간 원. 카드 제목 아이콘(16) / 줌아웃 마커(44) 공용.
class TextGlyph extends StatelessWidget {
  const TextGlyph({super.key, required this.size, this.withBorder = false});

  final double size;

  /// 줌아웃 마커처럼 단독으로 쓸 때 흰 테두리 + 그림자.
  final bool withBorder;

  @override
  Widget build(BuildContext context) {
    final double inner = size * 0.5;
    final double lineH = (size * 0.08).clamp(1.4, 4.0);
    final int lines = size >= 24 ? 3 : 2;
    const List<double> widths = [0.62, 0.82, 0.5];

    final List<Widget> lineWidgets = [];
    for (int i = 0; i < lines; i++) {
      lineWidgets.add(Container(
        width: inner * widths[i],
        height: lineH,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(lineH),
        ),
      ));
      if (i < lines - 1) lineWidgets.add(SizedBox(height: lineH * 1.1));
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TextMarkerTokens.glyphBlue,
        shape: BoxShape.circle,
        border: withBorder
            ? Border.all(
                color: Colors.white,
                width: (size * 0.06).clamp(1.5, 3.0),
              )
            : null,
        boxShadow: withBorder
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: lineWidgets,
        ),
      ),
    );
  }
}

/// 말풍선 모양 ShapeBorder — 둥근 사각형 본체 + 하단 중앙 꼬리를
/// "하나의 연속 외곽선"으로 그린다. 카드와 꼬리를 따로 그릴 때 생기던
/// 경계선/그림자 이음새가 사라져 진짜 말풍선처럼 보인다.
/// 채움·테두리·그림자(ShapeDecoration.shadows)가 모두 이 외곽선을 공유.
class _SpeechBubbleShape extends ShapeBorder {
  const _SpeechBubbleShape();

  static const double radius = 16; // 본체 모서리
  static const double tailWidth = 18; // 꼬리 밑변
  static const double tailHeight = 9; // 꼬리 높이(아래로)
  static const Color borderColor = Color(0xFFE6E9EF);
  static const double borderWidth = 1;

  // 콘텐츠 영역이 꼬리를 침범하지 않도록 하단 inset 확보.
  @override
  EdgeInsetsGeometry get dimensions =>
      const EdgeInsets.only(bottom: tailHeight);

  Path _outline(Rect rect) {
    final double left = rect.left;
    final double top = rect.top;
    final double right = rect.right;
    final double bottom = rect.bottom - tailHeight; // 본체 하단(꼬리 제외)
    final double cx = rect.center.dx;
    const double r = radius;
    const double tw = tailWidth / 2;

    return Path()
      ..moveTo(left + r, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: const Radius.circular(r))
      ..lineTo(right, bottom - r)
      ..arcToPoint(Offset(right - r, bottom), radius: const Radius.circular(r))
      ..lineTo(cx + tw, bottom) // 꼬리 우측 밑
      ..lineTo(cx, bottom + tailHeight) // 꼬리 끝(=지도 좌표)
      ..lineTo(cx - tw, bottom) // 꼬리 좌측 밑
      ..lineTo(left + r, bottom)
      ..arcToPoint(Offset(left, bottom - r), radius: const Radius.circular(r))
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: const Radius.circular(r))
      ..close();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.drawPath(
      _outline(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..color = borderColor,
    );
  }

  @override
  ShapeBorder scale(double t) => const _SpeechBubbleShape();
}

/// 줌인 시 보이는 텍스트 카드 마커.
///
/// [title] 이 null 이면 "본문만" 변형. [maxLines] 로 본문 줄 수 제한(말줄임).
class TextMarkerCard extends StatelessWidget {
  const TextMarkerCard({
    super.key,
    this.title,
    required this.body,
    this.maxLines = 2,
    this.cardWidth = 184,
  });

  final String? title;
  final String body;
  final int maxLines;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final bool hasTitle = title != null && title!.trim().isNotEmpty;

    // 카드 본체 + 꼬리를 하나의 말풍선 ShapeDecoration 으로. 꼬리 끝이
    // 박스 하단 중앙(anchor 0.5,1.0)에 오므로 지도 좌표를 정확히 가리킨다.
    return Container(
      // 고정 너비 대신 최대 너비만 제한 → 내용에 맞춰 너비가 줄어든다.
      // (짧은 글은 좁게, 긴 글만 cardWidth 에서 줄바꿈)
      constraints: BoxConstraints(maxWidth: cardWidth),
      // 좌우 패딩을 0으로 두고 Row/Text 각각에 패딩을 적용.
      // 구분선은 패딩을 9로 줘서 텍스트(13)보다 양쪽 4px씩 더 길게 보이도록.
      padding: const EdgeInsets.only(
          top: 11, bottom: 11 + _SpeechBubbleShape.tailHeight),
      decoration: const ShapeDecoration(
        color: TextMarkerTokens.cardBg,
        shape: _SpeechBubbleShape(),
        shadows: [
          BoxShadow(
            color: Color(0x1A000000), // 10% — 부드럽게
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      // IntrinsicWidth: 자식들 중 가장 넓은 폭에 맞춰 카드 너비 결정(최대 cardWidth).
      // stretch: 구분선이 카드 너비를 꽉 채우도록.
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasTitle) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TextGlyph(size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.2,
                          color: TextMarkerTokens.titleText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              // 텍스트 패딩(13)보다 작게 줘서 양쪽 4px씩 더 길어 보임.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Container(height: 1, color: TextMarkerTokens.divider),
              ),
              const SizedBox(height: 7),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Text(
                body,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
                  height: 1.36,
                  color: TextMarkerTokens.bodyText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 줌아웃 시 보이는 텍스트 전용 마커. 원 글리프 + 제목 라벨(사진 마커 패밀리).
class TextMarkerDot extends StatelessWidget {
  const TextMarkerDot({
    super.key,
    required this.title,
    this.diameter = 44,
    this.count,
  });

  final String title;
  final double diameter;

  /// 2 이상이면 클러스터 — +N 뱃지 표시.
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            TextGlyph(size: diameter, withBorder: true),
            if (count != null && count! >= 2)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: TextMarkerTokens.badgeBlue,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '+${count! - 1}',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                      height: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // 지도 배경 위 가독성을 위해 흰색 halo(그림자) 적용.
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 12,
            height: 1.1,
            color: TextMarkerTokens.titleText,
            shadows: [
              Shadow(color: Colors.white, blurRadius: 2),
              Shadow(color: Colors.white, blurRadius: 2),
            ],
          ),
        ),
      ],
    );
  }
}
