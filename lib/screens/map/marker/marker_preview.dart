import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:unimal/service/image/image_service.dart';

class MarkerPreview extends StatefulWidget {
  const MarkerPreview({super.key});

  @override
  State<MarkerPreview> createState() => _MarkerPreviewState();
}

class _MarkerPreviewState extends State<MarkerPreview> {
  final ImageService imageService = ImageService();
  Uint8List? markerBytes;

  @override
  void initState() {
    super.initState();
    _loadMarkerImage();
  }

  Future<void> _loadMarkerImage() async {
    final ImageStream stream = await imageService.getImageStream();
    final Uint8List bytes = await imageService.createMarkerImage(stream);
    setState(() {
      markerBytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마커 이미지 미리보기')),
      body: Center(
        child: markerBytes == null
            ? const CircularProgressIndicator()
            : Image.memory(markerBytes!),
      ),
    );
  }
}