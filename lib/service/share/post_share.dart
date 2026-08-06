import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// 게시글 공유.
///
/// 설계: `server/unimal-server/docs/specs/2026-08-07-게시글-공유.md`
///
/// ## URL 을 여기서 만들지 않는다
///
/// [shareUrl] 은 서버가 완성해서 내려준 값이다(`BoardPost.shareUrl`). 앱에서
/// `'https://...' + boardId` 로 조립하면 **도메인이 바뀔 때 스토어 심사를 다시 받아야
/// 하고, 그동안 구버전 사용자들은 죽은 링크를 계속 퍼뜨린다.**
///
/// ## 텍스트에 URL 을 같이 넣는 이유
///
/// 카카오톡은 전달받은 텍스트 안의 URL 을 찾아 미리보기 카드를 만든다. 제목만
/// 보내면 카드가 안 뜨고, URL 만 보내면 무슨 글인지 알 수 없다. 둘 다 넣는다.
///
/// 미리보기 카드의 사진·제목은 이 텍스트가 아니라 **공유 페이지의 OG 태그**에서 온다.
/// 여기서 아무리 잘 써도 서버 OG 태그가 비어 있으면 카드는 안 뜬다.
class PostShare {
  const PostShare._();

  /// [context] 는 iPad 에서 공유 시트를 띄울 위치를 잡는 데 쓴다.
  /// iOS 는 팝오버 기준점이 없으면 예외를 던진다 — iPhone 에서만 테스트하면
  /// 놓치기 쉬운 부분이다.
  static Future<void> share({
    required BuildContext context,
    required String shareUrl,
    String? title,
  }) async {
    final headline = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : '스토맵에서 발견한 이야기';

    final box = context.findRenderObject() as RenderBox?;

    await Share.share(
      '$headline\n$shareUrl',
      subject: headline,
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }
}
