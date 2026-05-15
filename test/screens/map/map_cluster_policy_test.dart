import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('map clustering remains enabled through zoom 15 and opens at zoom 16', () {
    final source = File('lib/screens/map/map_naver.dart').readAsStringSync();

    expect(source, contains('enableZoomRange: const NInclusiveRange(0, 15)'));
    expect(source, contains('NInclusiveRange(13, 14): 85.0'));
    expect(source, contains('NInclusiveRange(15, 15): 60.0'));
    expect(source, contains('final nextZoom = camera.zoom < 16 ? 16.0 : camera.zoom;'));
  });
}
