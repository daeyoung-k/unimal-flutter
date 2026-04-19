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
}
