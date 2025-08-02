import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:unimal/screens/test_etc.dart';

class TestEtcPreview extends StatefulWidget {
  const TestEtcPreview({super.key});

  @override
  State<TestEtcPreview> createState() => _TestEtcPreviewState();
}

class _TestEtcPreviewState extends State<TestEtcPreview> {
  Uint8List? markerBytes;

  @override
  void initState() {
    super.initState();
    _loadMarkerImage();
  }

  Future<void> _loadMarkerImage() async {
    final Uint8List bytes = await TestEtc.getImageBytes();
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