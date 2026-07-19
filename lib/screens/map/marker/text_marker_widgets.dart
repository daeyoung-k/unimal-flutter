import 'package:flutter/material.dart';

/// 텍스트 전용 커스텀 마커 위젯 모음.
///
/// 피그마 "18 텍스트 마커 변형 시트" 확정안(점 앵커 + 꼬리 없는 말풍선) 기준.
/// - 줌인: [TextBubbleMarker] — 흰 콘텐츠 카드(꼬리 없음) + 4px 아래 점 앵커
/// - 카드: [TextMarkerCard] — 제목+시간 행 + 본문 2줄, 고정 폭 204(본문 180)
/// - 점: [TextDotGlyph] — 32dp 화이트 원 + 블루 챗 글리프 (튀어나온 꼬리 없음)
///
/// 구 디자인(파란 말풍선 + 가짜 줄 3개)에서 **색 반전**했다: 화이트 면 +
/// 블루 글리프. "블루는 배경이 아니라 강조 액센트로만" 톤 가이드와 일치.
/// 점 마커가 좌표 앵커(원 바닥 = 지도 좌표, 사진 마커와 동일)를 담당하고,
/// 말풍선 카드는 그 위에 4px 간격으로 떠 있다 (카드 자체엔 꼬리 없음).
///
/// 이 위젯들은 `NOverlayImage.fromWidget(widget:, size:, context:)` 으로
/// 비트맵 변환해 네이버 지도 마커 아이콘으로 사용한다. Theme.extension 미정착
/// 상태라 색은 토큰 상수를 직접 참조한다 (off-tree 렌더 안정성).
/// 줌아웃 점(클러스터/스택 +N 뱃지 합성 필요)은 바이트 파이프라인이라
/// `MarkerImageFactory.createTextDotImage` 가 [paintTextDot] 로 같은 그림을 그린다.
class TextMarkerTokens {
  // app_colors.dart 라이트 토큰과 동기화 (마커 비트맵은 라이트 팔레트 고정).
  static const Color glyph = Color(0xFF4D91FF); // primaryStrong
  static const Color badge = Color(0xFF3578E5); // primary
  static const Color surface = Color(0xFFFFFFFF); // surface (카드/점 면)
  static const Color border = Color(0xFFE5E7EB); // border (1px 테두리)
  static const Color titleText = Color(0xFF1A1A2E); // textPrimary
  static const Color bodyText = Color(0xFF374151); // textSecondary
  static const Color timeText = Color(0xFF9CA3AF); // textMuted
}

/// 점 마커 기준 프레임 (피그마 스펙 시트 기준, 단위 dp). 원 32x32.
/// 피그마의 다이아 꼬리는 원 뒤에 완전히 숨는 장식이라 그리지 않는다
/// (2026-07-14 피드백: 튀어나온 꼬리는 디자인에 없음). 좌표 앵커는
/// 사진 마커와 동일하게 원 바닥(anchor 0.5, 1.0).
const double kTextDotFrameW = 32.0;
const double kTextDotFrameH = 32.0;

/// 텍스트 점 마커 그림 — 피그마 "text-marker-dot" 노드의 기하를 그대로 옮겼다.
/// - 화이트 원 32dp + border 1dp (외곽 = 정확히 32dp)
/// - 챗 글리프: primaryStrong 라운드 사각 15 x 11.5 (r4) + 좌하단 작은 꼬리
/// - 원 바닥 = (16, 32) = 지도 좌표 (anchor 0.5, 1.0)
///
/// [origin]은 32x32 기준 프레임의 좌상단이 놓일 캔버스 위치, [unit]은 1dp당 px.
/// 위젯([TextDotGlyph])과 바이트 팩토리([MarkerImageFactory.createTextDotImage])가
/// 이 함수 하나로 같은 모양을 그린다.
void paintTextDot(
  Canvas canvas, {
  required Offset origin,
  required double unit,
  bool withShadow = false,
  Color face = TextMarkerTokens.surface,
  Color border = TextMarkerTokens.border,
  Color glyph = TextMarkerTokens.glyph,
}) {
  Offset at(double x, double y) =>
      Offset(origin.dx + x * unit, origin.dy + y * unit);

  final facePaint = Paint()
    ..color = face
    ..isAntiAlias = true;
  final borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = unit // 1dp
    ..color = border
    ..isAntiAlias = true;

  final circleCenter = at(16, 16);

  if (withShadow) {
    // 피그마: 점 svg 자체에 은은한 드롭 섀도.
    final shadowPath = Path()
      ..addOval(Rect.fromCircle(center: circleCenter, radius: 16 * unit));
    canvas.drawShadow(shadowPath, const Color(0x22000000), unit, false);
  }

  // 원 — 테두리는 안쪽으로 (외곽이 정확히 32dp).
  canvas.drawCircle(circleCenter, 16 * unit, facePaint);
  canvas.drawCircle(circleCenter, 15.5 * unit, borderPaint);

  // 챗 글리프 — 블루 라운드 사각(8.5,9 ~ 15x11.5, r4) + 좌하단 꼬리.
  final glyphPaint = Paint()
    ..color = glyph
    ..isAntiAlias = true;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
          origin.dx + 8.5 * unit, origin.dy + 9 * unit, 15 * unit, 11.5 * unit),
      Radius.circular(4 * unit),
    ),
    glyphPaint,
  );
  final glyphTail = Path()
    ..moveTo(at(11, 19.5).dx, at(11, 19.5).dy)
    ..lineTo(at(16, 19.5).dx, at(16, 19.5).dy)
    ..lineTo(at(11.8, 23.5).dx, at(11.8, 23.5).dy)
    ..close();
  canvas.drawPath(glyphTail, glyphPaint);
}

/// 점 앵커 위젯 — [TextBubbleMarker] 에서 카드 아래에 붙는다.
/// [diameter] = 원 지름(dp). 원 바닥이 위젯 하단 중앙(=지도 좌표).
class TextDotGlyph extends StatelessWidget {
  const TextDotGlyph({super.key, this.diameter = 32});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final double unit = diameter / kTextDotFrameW;
    // 좌우 2px·상단 1px 여유 (테두리 안티앨리어싱). 하단은 여유 없이
    // 원 바닥 = 위젯 바닥 — 앵커(0.5, 1.0) 정합.
    return CustomPaint(
      size: Size(diameter + 4, kTextDotFrameH * unit + 1),
      painter: _TextDotPainter(unit),
    );
  }
}

class _TextDotPainter extends CustomPainter {
  const _TextDotPainter(this.unit);

  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    paintTextDot(
      canvas,
      origin: Offset(
        (size.width - kTextDotFrameW * unit) / 2,
        size.height - kTextDotFrameH * unit,
      ),
      unit: unit,
    );
  }

  @override
  bool shouldRepaint(covariant _TextDotPainter old) => old.unit != unit;
}

/// 줌인 시 보이는 텍스트 카드(말풍선). 꼬리 없음 — 좌표 앵커는 아래 점이 담당.
///
/// 피그마 "text-marker-card": 고정 폭 204 (패딩 12 → 본문 폭 180 고정),
/// radius 14 · border 1 · 그림자 y2 blur8 8% · 제목/시간 gap 8 · 헤더-본문 gap 4.
/// [title] 이 null 이면 "본문만" 변형(시간 행 → 본문). [maxLines] 로 본문 줄 수 제한.
/// [time] 은 상대 시간 문자열(예: "1시간 전"), null 이면 표시 안 함.
class TextMarkerCard extends StatelessWidget {
  const TextMarkerCard({
    super.key,
    this.title,
    required this.body,
    this.time,
    this.maxLines = 2,
    this.cardWidth = 204,
  });

  final String? title;
  final String body;
  final String? time;
  final int maxLines;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final bool hasTitle = title != null && title!.trim().isNotEmpty;
    final bool hasTime = time != null && time!.trim().isNotEmpty;

    const titleStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w600,
      fontSize: 13,
      height: 1.2,
      color: TextMarkerTokens.titleText,
    );
    const timeStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 10,
      height: 1.2,
      color: TextMarkerTokens.timeText,
    );

    Widget? header;
    if (hasTitle) {
      header = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(title!,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
          ),
          if (hasTime) ...[
            const SizedBox(width: 8),
            Text(time!, maxLines: 1, style: timeStyle),
          ],
        ],
      );
    } else if (hasTime) {
      header = Text(time!, maxLines: 1, style: timeStyle);
    }

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TextMarkerTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TextMarkerTokens.border, width: 1),
        boxShadow: const [
          // 피그마: y2 blur8 8%. 화이트 톤이라 그림자는 최소한.
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            header,
            const SizedBox(height: 4),
          ],
          Text(
            body,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.45,
              color: TextMarkerTokens.bodyText,
            ),
          ),
        ],
      ),
    );
  }
}

/// 줌인 텍스트 마커 = 카드(위) + 4px 간격 + 점 앵커(아래).
/// 하단 중앙(점의 원 바닥)이 지도 좌표(anchor 0.5, 1.0)를 가리킨다.
/// 카드와 점을 한 위젯으로 합성해 `fromWidget` 한 번으로 비트맵화한다.
class TextBubbleMarker extends StatelessWidget {
  const TextBubbleMarker({
    super.key,
    this.title,
    required this.body,
    this.time,
    this.maxLines = 2,
    this.cardWidth = 204,
  });

  final String? title;
  final String body;
  final String? time;
  final int maxLines;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextMarkerCard(
          title: title,
          body: body,
          time: time,
          maxLines: maxLines,
          cardWidth: cardWidth,
        ),
        const SizedBox(height: 4),
        const TextDotGlyph(),
      ],
    );
  }
}
