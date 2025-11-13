import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeepLink {
  final AppLinks _appLinks = AppLinks();
  Uri? _initialUri;

  Uri? get initialUri => _initialUri;

  Future<void> init() async {
    // 앱이 실행 중일 때
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    
    // 앱이 종료된 상태에서 열릴 때
    _initialUri = await _appLinks.getInitialLink();
  }

  void handleInitialDeepLink() {
    if (_initialUri != null) {
      // 앱이 완전히 준비된 후 딥링크 처리
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleDeepLink(_initialUri!);
      });
    }
  }

  void _handleDeepLink(Uri uri) {
    // 상세 게시판 페이지 이동
    if (uri.path == '/detail-board') {
      final id = uri.queryParameters['id'];
      
      // GetX로 네비게이션
      Get.toNamed('/detail-board', parameters: {
        'id': id ?? '',
      });
    }
  }

}