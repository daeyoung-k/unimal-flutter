import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async'; // Added for Completer
import 'dart:typed_data';

class ImageService {

  Future<ImageStream> getImageStream() async {
    final NetworkImage assetImage = NetworkImage("https://i.pravatar.cc/300");
    final ImageStream stream = assetImage.resolve(ImageConfiguration.empty);
    return stream;
  }

  Future<Uint8List> createMarkerImage(ImageStream stream) async {
    final Completer<ui.Image> completer = Completer<ui.Image>();

    stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info.image);
    }));

    final loadedImage = await completer.future;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    const double size = 200.0;

    final center = Offset(size / 2, size / 2);
    final radius = size / 2;

    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clipPath);

    final Rect dstRect = Rect.fromCircle(center: center, radius: radius);
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
