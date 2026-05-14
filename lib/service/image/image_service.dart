import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async'; // Added for Completer
import 'dart:math' as math;
import 'dart:typed_data';

class ImageService {

  Future<ImageStream> getImageStream(String url) async {
    final NetworkImage assetImage = NetworkImage(url);
    final ImageStream stream = assetImage.resolve(ImageConfiguration.empty);
    return stream;
  }

  Future<Uint8List> createMarkerImage(ImageStream stream) async {
    final Completer<ui.Image> completer = Completer<ui.Image>();

    stream.addListener(ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (exception, stackTrace) {
        if (!completer.isCompleted) completer.completeError(exception, stackTrace);
      },
    ));

    final loadedImage = await completer.future;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    const double size = 200.0;

    final center = Offset(size / 2, size / 2);
    const double borderWidth = 8.0;
    final outerRadius = size / 2;
    final innerRadius = outerRadius - borderWidth;

    // 흰색 테두리 원
    canvas.drawCircle(center, outerRadius, Paint()..color = Colors.white);

    // 이미지를 내부 원에 클립하여 그리기
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.clipPath(clipPath);

    final Rect dstRect = Rect.fromCircle(center: center, radius: innerRadius);
    final Rect srcRect = Rect.fromLTWH(
        0, 0, loadedImage.width.toDouble(), loadedImage.height.toDouble());

    canvas.drawImageRect(loadedImage, srcRect, dstRect, paint);

    final ui.Image finalImage =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 마커 이미지 위에 우상단 +N 뱃지를 합성해 새 PNG bytes 반환.
  /// 클러스터 마커용. base는 createMarkerImage 결과(200x200 가정).
  Future<Uint8List> addClusterBadge(Uint8List baseBytes, int count) async {
    final codec = await ui.instantiateImageCodec(baseBytes);
    final frame = await codec.getNextFrame();
    final base = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double size = 200.0;

    // base 이미지 그리기
    canvas.drawImageRect(
      base,
      Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()),
      Rect.fromLTWH(0, 0, size, size),
      Paint(),
    );

    // 우상단 뱃지
    const double badgeRadius = 40.0;
    final badgeCenter = Offset(size - badgeRadius, badgeRadius);
    // 외곽 흰 테두리
    canvas.drawCircle(
      badgeCenter,
      badgeRadius + 4,
      Paint()..color = Colors.white,
    );
    // 브랜드 푸른색 원 (선택 핀 마커와 동일 톤으로 통일)
    canvas.drawCircle(
      badgeCenter,
      badgeRadius,
      Paint()..color = const Color(0xFF3578E5),
    );
    // +N 텍스트
    final tp = TextPainter(
      text: TextSpan(
        text: '+$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 44,
          fontWeight: FontWeight.w700,
          fontFamily: 'Pretendard',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(
        badgeCenter.dx - tp.width / 2,
        badgeCenter.dy - tp.height / 2,
      ),
    );

    final composedImage =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData =
        await composedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 선택된 마커에 사용할 단색 푸른 핀 이미지를 만들어 PNG bytes 반환.
  /// 모양: 티어드롭(원형 머리 + 뾰족 꼬리). 가운데 작은 흰 점.
  /// 좌표 anchor = bottom-center(NPoint(0.5, 1.0))에 맞춰 꼬리 끝이 캔버스 맨 아래.
  Future<Uint8List> createPinMarkerImage() async {
    const double width = 200.0;
    const double height = 256.0;
    const Offset headCenter = Offset(100, 95);
    const double headRadius = 80.0;
    const Offset tailTip = Offset(100, 252);
    // 머리 원의 수직 아래 기준 좌우 각도. 35도면 꼬리 폭이 적당.
    const double tailHalfAngle = 35 * math.pi / 180;
    const Color pinColor = Color(0xFF3578E5);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final leftAngle = math.pi / 2 + tailHalfAngle;
    final leftAnchor = Offset(
      headCenter.dx + headRadius * math.cos(leftAngle),
      headCenter.dy + headRadius * math.sin(leftAngle),
    );

    // 좌측 꼬리 시작점에서 시계방향으로 머리 원의 위쪽을 둘러 우측 꼬리 시작점까지.
    // sweep = 2π - 2*tailHalfAngle (꼬리에 해당하는 호 부분만 제외).
    final pinPath = Path()
      ..moveTo(leftAnchor.dx, leftAnchor.dy)
      ..arcTo(
        Rect.fromCircle(center: headCenter, radius: headRadius),
        leftAngle,
        2 * math.pi - 2 * tailHalfAngle,
        false,
      )
      ..lineTo(tailTip.dx, tailTip.dy)
      ..close();

    canvas.drawShadow(pinPath, Colors.black.withValues(alpha: 0.25), 4, false);
    canvas.drawPath(pinPath, Paint()..color = pinColor);
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(headCenter, 22, Paint()..color = Colors.white);

    final image =
        await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
