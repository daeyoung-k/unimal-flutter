import 'package:flutter/material.dart';

/// 텍스트 전용 커스텀 마커 위젯 모음.
///
/// 피그마 "18 텍스트 마커 변형 시트" 확정안(점 앵커 + 꼬리 없는 말풍선) 기준.
/// - 카드: [TextMarkerCard] — 제목+시간 행 + 본문 2줄, 고정 폭 204(본문 180)
///
/// 구 디자인(파란 말풍선 + 가짜 줄 3개)에서 **색 반전**했다: 화이트 면 +
/// 블루 글리프. "블루는 배경이 아니라 강조 액센트로만" 톤 가이드와 일치.
///
/// **점은 말풍선 아이콘에 그리지 않는다** (2026-07-29 변경). 이전에는
/// 카드 아래에 점 그림을 함께 합성하고, 말풍선이 뜰 때 밑의 실제 점 마커를
/// 충돌 숨김으로 가렸다. 그래서 점이 사실상 두 개(실제 점 + 아이콘 안 점)
/// 존재했고 **둘의 크기를 사람이 맞춰줘야** 했다(어긋나면 전환 순간 튄다).
/// 지금은 카드가 앵커 오프셋(`kTextCardAnchor`)으로 점 위에 떠 있고 그 아래
/// **실제 점 마커가 그대로 보인다** — 점은 하나뿐이므로 맞출 대상이 없고,
/// 페이드 중 점이 겹쳐 그려지는 일도 없다.
///
/// (연혁: 2026-07-29 ~ 07-30 사이엔 아이콘 하단을 [kTextBubbleDotReserve]
/// 만큼 **투명하게 비워** 점 자리를 만들었다(TextBubbleMarker 위젯). 그런데
/// 네이버 지도 마커의 터치 영역은 투명 픽셀 포함 아이콘 사각형 전체라, 그
/// 투명 띠가 이웃 점 마커의 탭을 가로챘다 — 겹친 말풍선 아래 점을 탭하면
/// 옆 글이 열리는 버그. 그래서 아이콘을 카드만으로 줄이고 위치는 앵커로
/// 해결했다. 상세는 marker_constants.dart 의 kTextCardSize 주석.)
///
/// 이 위젯들은 `NOverlayImage.fromWidget(widget:, size:, context:)` 으로
/// 비트맵 변환해 네이버 지도 마커 아이콘으로 사용한다. Theme.extension 미정착
/// 상태라 색은 토큰 상수를 직접 참조한다 (off-tree 렌더 안정성).
/// 점 마커 자체(클러스터/스택 +N 뱃지 합성 필요)는 바이트 파이프라인이라
/// `MarkerImageFactory.createTextDotImage` 가 [paintTextDot] 로 그린다.
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

/// 말풍선 카드와 그 아래 점 사이 간격 (피그마 18: 4px).
const double kTextBubbleCardGap = 4.0;

/// 말풍선 카드 바닥 ~ 지도 좌표 거리 = 점 원 지름 + 카드-점 간격.
///
/// 지금은 아이콘에 투명 여백을 두지 않고(파일 상단 연혁 참고) 이 거리를
/// 앵커 오프셋으로 처리한다 — marker_constants.dart 의 `kTextCardDotReserve`
/// 가 같은 값을 별도로 정의한다 (한쪽을 바꾸면 반드시 다른 쪽도 바꿀 것).
const double kTextBubbleDotReserve = kTextDotFrameH + kTextBubbleCardGap;

/// 텍스트 점 마커 그림 — 피그마 "text-marker-dot" 노드의 기하를 그대로 옮겼다.
/// - 화이트 원 32dp + border 1dp (외곽 = 정확히 32dp)
/// - 챗 글리프: primaryStrong 라운드 사각 15 x 11.5 (r4) + 좌하단 작은 꼬리
/// - 원 바닥 = (16, 32) = 지도 좌표 (anchor 0.5, 1.0)
///
/// [origin]은 32x32 기준 프레임의 좌상단이 놓일 캔버스 위치, [unit]은 1dp당 px.
/// 지금은 바이트 팩토리(`MarkerImageFactory.createTextDotImage`) 하나만 이 함수를
/// 쓴다 — 말풍선 아이콘은 점을 그리지 않기 때문이다(2026-07-29). 점 그림이
/// 필요한 곳이 다시 생기면 반드시 이 함수를 경유해 모양을 한 곳에서 관리할 것.
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

// (TextBubbleMarker 위젯은 삭제됨 — 2026-07-30. 하단 투명 점 자리가 마커
// 터치 영역에 포함돼 이웃 점 마커의 탭을 가로채는 문제로, 아이콘은
// TextMarkerCard 만 쓰고 점 자리는 앵커 오프셋(kTextCardAnchor)으로 처리한다.)
