import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 앱 외부에서 들어오는 링크 처리.
///
/// 설계: `server/unimal-server/docs/specs/2026-08-07-게시글-공유.md`
///
/// ## 2026-08-07 이전에는 실제로 동작한 적이 없다
///
/// 이 클래스는 예전부터 있었지만 **AndroidManifest 와 Info.plist 에 딥링크 스킴이
/// 등록돼 있지 않았다.** OS 가 이벤트를 만들어주지 않으니 [AppLinks] 가 받을 게
/// 없었던 것이다. FCM 푸시 라우팅은 별도 경로(`Get.toNamed` 직접 호출)라 이 사실이
/// 드러나지 않았다.
///
/// 게시글 공유를 붙이면서 `stomap` 스킴을 등록했고, 그때부터 여기가 진짜로 쓰인다.
///
/// ## 받는 형태가 두 가지다
///
/// | 형태 | 출처 |
/// |---|---|
/// | `stomap://post?id={boardId}` | 공유 웹페이지의 "앱에서 이어보기" |
/// | `.../detail-board?id={boardId}` | 예전 형식. 호환용으로 남긴다 |
///
/// 커스텀 스킴에서는 `stomap` 다음 조각이 [Uri.path] 가 아니라 [Uri.host] 로 들어온다.
/// `stomap://post?id=x` 의 host 는 `post`, path 는 빈 문자열이다. 예전 코드가
/// `uri.path == '/detail-board'` 만 봤기 때문에, 스킴을 등록해도 그대로는 아무 일도
/// 일어나지 않았을 것이다.
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
    final boardId = _boardIdOf(uri);
    if (boardId == null || boardId.isEmpty) return;

    Get.toNamed('/detail-board', parameters: {'id': boardId});
  }

  /// 링크에서 게시글 ID 를 뽑는다. 게시글 링크가 아니면 null.
  ///
  /// **모르는 링크는 조용히 무시한다.** 딥링크는 사용자가 아니라 외부(브라우저·다른 앱)가
  /// 보내는 입력이라 뭐가 들어올지 통제할 수 없다. 여기서 화면을 띄우거나 에러를
  /// 내면 앱이 남의 손에 흔들린다.
  String? _boardIdOf(Uri uri) {
    final id = uri.queryParameters['id'];
    if (id == null) return null;

    // stomap://post?id=x  →  host = 'post'
    if (uri.host == 'post') return id;

    // https://.../detail-board?id=x  →  path = '/detail-board'
    if (uri.path == '/detail-board') return id;

    return null;
  }
}
