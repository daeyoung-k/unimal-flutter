import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async'; // Added for Completer
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
    // 코랄 원
    canvas.drawCircle(
      badgeCenter,
      badgeRadius,
      Paint()..color = const Color(0xFFFF6B6B),
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
}
